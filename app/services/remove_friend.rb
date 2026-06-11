# frozen_string_literal: true

module FinanceTracker
  # Removes an account from an account's one-way friend list by username.
  class RemoveFriend
    class UnknownUserError < StandardError; end
    class NotFriendError < StandardError; end

    def self.call(account:, username:)
      username = username.to_s.strip
      target = Account.first(username:)
      raise UnknownUserError, 'Unknown user' unless target

      unless account.friends_dataset.where(Sequel[:accounts][:id] => target.id).first
        raise NotFriendError, 'Not in your friends list'
      end

      account.remove_friend(target)
      target
    end
  end
end
