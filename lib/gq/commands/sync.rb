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
      puts "Rebasing #{branch.cyan}..."

      unless @git.branches(:remote).include?("#{@git.remotes.first}/#{branch}")
        if Shell.prompt?("Remote branch #{branch.cyan} does not exist. Delete?")
          puts "Deleting #{branch.cyan}..."
          parent = @git.parent_of(branch)
          @stack[branch].children.each do |child|
            puts indent("Setting parent of #{child.cyan} to #{parent.cyan}".green)
            @stack[child].parent = parent
            @git.track(child, parent)
          end
          puts indent("Deleting #{branch.cyan}".red)
          @git.checkout('master')
          @git.branch("-D", branch)
        end
        
        next
      end

      @git.pull(remote: @git.remotes.first, remote_branch: branch)

      parent = @git.parent_of(branch)
      next if parent == '' # We may be updating the root branch, which has no parent

      @git.rebase(branch, parent)
    end

    @stack.refresh
  end
end
end