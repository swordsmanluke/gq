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
    remote = args.first || @git.remotes.first
    puts "Fetching from remote #{remote.cyan}..."
    @git.fetch(remote)

    @stack.current_stack.reverse.each do |branch|
      puts "Rebasing #{branch.cyan}..."

      unless @git.branches(:remote).map(&:name).include?("#{@git.remotes.first}/#{branch}")
        if Shell.prompt?("Remote branch #{branch.cyan} does not exist. Delete?")
          puts "Deleting #{branch.cyan}..."
          parent = @git.parent_of(branch)
          @stack.branches[branch].children.each do |child|
            puts indent("Setting parent of #{child.cyan} to #{parent.cyan}".green)
            @stack.branches[child].parent = parent
            @git.track(child, parent)
          end
          puts indent("Deleting #{branch.cyan}".red)
          @git.checkout('master')
          @git.delete_branch(branch)
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