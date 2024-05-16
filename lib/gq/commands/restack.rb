# frozen_string_literal: true
require_relative '../shell'
require_relative 'command'

module Gq
class Restack < Command
  COMMAND = ["restack"]

  def initialize(stack, git=::Gq::Git)
    super(stack, git)
    @queue = []
  end

  def self.documentation
    "Rebase branches on their parents"
  end

  def call(*args)
    push(@stack.root.name)

    cur_branch = @git.current_branch.name

    while (branch = pop)
      parent = @git.parent_of(branch)
      next if parent == ''

      @git.rebase(branch, parent)
      puts "Rebased #{branch.cyan} -> #{parent&.cyan}"
      @stack.branches[branch].children.each { push _1 }
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