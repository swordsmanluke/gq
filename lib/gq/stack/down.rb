# frozen_string_literal: true
require_relative '../shell'
require_relative 'command'

module Gq::Stack
class Down < Command
  COMMAND = ["down", "bd"]

  def self.documentation
    "Move down the stack toward the root."
  end

  def call(*args)
    # Checkout the parent of the current branch
    # or print an error if there is no parent.
    current = @stack.branches[@git.current_branch.name]
    if current.parent.nil? || current.parent.empty?
      self_destruct "You are already at the bottom of the stack."
    else
      @git.checkout(current.parent)
    end
  end
end
end