# frozen_string_literal: true
require_relative '../shell'
require_relative 'command'

module Gq
class Sync < Command
  COMMAND = ["sync"]

  def self.documentation
    "Pull from remote, then restack."
  end

  def call(*args)
    puts "Fetching from remote #{@git.remotes.first.cyan}..."
    @git.fetch

    @stack.current_stack.reverse.each do |branch|
      @git.pull
      parent = @git.parent_of(branch)
      next if parent == '' # We may be updating the root branch, which has no parent

      @git.rebase(branch, parent)
      puts "Rebased #{branch.cyan} on #{parent&.cyan}"
    end
  end
end
end