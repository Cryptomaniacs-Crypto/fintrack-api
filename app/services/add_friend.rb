# frozen_string_literal: true

module FinanceTracker
  # Adds another account to an account's one-way friend list by username.
  # Directional and not auto-reciprocal -- see migration 014.
  class AddFriend
    class UnknownUserError < StandardError; end
    class SelfFriendError < StandardError; end
    class AlreadyFriendError < StandardError; end

    def self.call(account:, username:)
      target = lookup!(username)
      raise SelfFriendError, 'You cannot add yourself as a friend' if target.id == account.id
      raise AlreadyFriendError, 'Already in your friends list' if friend?(account, target)

      account.add_friend(target)
      target
    end

    def self.lookup!(username)
      username = username.to_s.strip
      raise UnknownUserError, 'Unknown user' if username.empty?

      Account.first(username:) || raise(UnknownUserError, 'Unknown user')
    end

    def self.friend?(account, target)
      account.friends_dataset.where(Sequel[:accounts][:id] => target.id).any?
    end
  end
end
