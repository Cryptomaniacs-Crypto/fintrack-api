# frozen_string_literal: true

module FinanceTracker
  # OAuth-style authorization scope carried inside an AuthToken.
  #
  # A scope is a space-separated list of `resource:permission` grants, e.g.
  # `"wallets:read transactions:write"`. The wildcard resource `*` matches any
  # resource, and `write` implies `read`. Two named scopes ship today:
  #   FULL      = "*:write"  (a full session token — write implies read)
  #   READ_ONLY = "*:read"   (a reduced API key handed to a read-only deputy)
  #
  # Policies ask `can_read?`/`can_write?` for their resource string before
  # applying role/ownership logic, so a leaked READ_ONLY key can never mutate
  # data even if the underlying account holds write-capable roles.
  #
  # Resources in this API: accounts, wallets, categories, transactions.
  class AuthScope
    ALL = '*'
    READ = 'read'
    WRITE = 'write'
    FULL = '*:write'
    READ_ONLY = '*:read'

    SEPARATOR = ' '
    DIVIDER = ':'

    RESOURCES = %w[accounts wallets categories transactions *].freeze
    PERMISSIONS = %w[read write].freeze

    def initialize(scopes = FULL)
      @scopes_str = scopes
      @scopes = {}
      scopes.split(SEPARATOR).each { |scope| add_scope(scope) }
    end

    def can_read?(resource)
      readable?(ALL) || readable?(resource)
    end

    def can_write?(resource)
      writeable?(ALL) || writeable?(resource)
    end

    def to_s
      @scopes_str
    end

    # True when every grant in this scope is satisfiable by parent_scope.
    # Used to enforce downscope-only token minting: a caller cannot request
    # a token that exceeds their own current scope.
    def subset_of?(parent_scope)
      @scopes.all? do |resource, permissions|
        permissions.all? do |permission|
          permission == WRITE ? parent_scope.can_write?(resource) : parent_scope.can_read?(resource)
        end
      end
    end

    # True when every resource and permission token is from the known set.
    # Rejects arbitrary strings before they reach the subset check.
    def valid?
      @scopes.all? do |resource, permissions|
        RESOURCES.include?(resource) && permissions.all? { |p| PERMISSIONS.include?(p) }
      end
    end

    private

    # `write` implies `read`: a write grant satisfies a read check too.
    def readable?(resource)
      writeable?(resource) || permission_granted?(resource, READ)
    end

    def writeable?(resource)
      permission_granted?(resource, WRITE)
    end

    def permission_granted?(resource, permission)
      @scopes[resource]&.include?(permission) || false
    end

    def add_scope(scope)
      resource, permission = scope.split(DIVIDER)
      @scopes[resource] ||= []
      @scopes[resource] << permission
    end
  end
end
