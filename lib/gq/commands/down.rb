# frozen_string_literal: true
require_relative '../shell'
require_relative 'command'

class Down < Command
  COMMAND = ["down", "bd"]

  def self.documentation
    "Move down the commands toward the root."
  end

  def call(*args)
    # Checkout the parent of the current branch
    # or print an error if there is no parent.
    current = @stack.branches[@git.current_branch.name]
    if current.parent.nil? || current.parent.empty?
      self_destruct "You are already at the bottom of the commands."
    else
      @git.checkout(current.parent)
    end
  end
end
