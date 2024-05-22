# frozen_string_literal: true
require_relative '../shell'
require_relative 'command'

class Top < Command
  COMMAND = ["top", "bt"]

  def self.documentation
    "Move to the highest branch away from root."
  end

  def call(*args)
    # Checkout the next child of the current branch
    # Prompting the user if there are multiple children
    # or printing an error if there are none.
    current = @stack.current_branch
    self_destruct("Already at the top") if current.children.empty?

    until current.children.empty?
      if current.children.size == 1
        @git.checkout(current.children.first)
      else
        child = Shell.prompt("Multiple branches - choose one", options: current.children)
        if child
          @git.checkout(child)
        else
          self_destruct("Top command cancelled.")
        end
      end
      current = @stack.current_branch
    end

    puts `git status`
  end
end
