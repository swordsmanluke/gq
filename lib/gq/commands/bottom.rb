# frozen_string_literal: true
require_relative '../shell'
require_relative 'command'

class Bottom < Command
  COMMAND = ["bottom", "bb"]

  def self.documentation
    "Move down the branches to the last branch above the root."
  end

  def call(*args)
    # Checkout the parent of the current branch
    # or print an error if there is no parent.
    current = @stack.branches[@git.current_branch.name]
    if is_bottom?(current.parent)
      self_destruct "You are already at the bottom of the stack."
    end

    until is_bottom?(current.parent)
      @git.checkout(current.parent)
      current = @stack.current_branch
    end

    puts "Checked out branch #{current.name.cyan}\n"
    puts `git status`
  end

  def is_bottom?(branch)
    branch.nil? || branch.empty? || branch == @stack.config.root_branch
  end
end