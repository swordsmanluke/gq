# frozen_string_literal: true
require_relative '../shell'
require_relative 'command'

module Gq
class Restack < Command
  COMMAND = ["restack"]

  def initialize(stack, git = nil)
    super(stack, git)
    @queue = []
  end

  def self.documentation
    "Rebase branches on their parents"
  end

  def call(*args)
    push(@stack.root)

    cur_branch = @git.current_branch

    while (branch = pop)
      parent = @git.parent_of(branch.name)
      @git.rebase(branch.name, parent)
      puts "Rebased #{branch.name.cyan} -> #{parent.cyan}"
      branch.children.each { push _1 }
    end

    @git.checkout(cur_branch)
  end

  def push(branch)
    @queue << branch
  end

  def pop
    return nil if @queue.empty?

    @queue.shift
  end
end
end