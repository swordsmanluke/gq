# frozen_string_literal: true
require_relative '../shell'
require_relative 'command'

module Gq
class Squish < Command
  COMMAND = ["squish", "sq"]

  def self.documentation
    "Merge the current branch with its parent"
  end

  def call(*args)
    if args.include? "--all"
      puts "(Not actually) Squishing this branch and children down to root!"
    end

    parent = @stack.current_branch.parent
    me = @stack.current_branch.name
    @git.checkout(parent)
    @git.commit_diff(parent, me).reverse.each do |(sha, _)|
      @git.cherrypick(sha)
    end

    if @git.commit_diff(parent, me).present?
      self_destruct "Failed to merge #{me} -> #{parent}"
    end

    @git.delete_branch(me)
    @stack = Stack.refresh(@git)
  end
end
end