# frozen_string_literal: true
require_relative '../shell'
require_relative 'command'

module Gq
class Up < Command
  COMMAND = ["up", "bu"]

  def self.documentation
    "Move up the commands away from root."
  end

  def call(*args)
    # Checkout the next child of the current branch
    # Prompting the user if there are multiple children
    # or printing an error if there are none.
    current = @stack.current_branch
    if current.children.empty?
      self_destruct "You are already at the top of the commands."
    elsif current.children.size == 1
      @git.checkout(current.children.first)
    else
      child = ::Gq::Shell.prompt("Multiple branches - choose one", options: current.children)
      @git.checkout(child) if child
    end
  end
end
end