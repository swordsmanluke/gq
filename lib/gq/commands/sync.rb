# frozen_string_literal: true
require_relative '../shell'
require_relative 'command'

class Sync < Command
  COMMAND = ["sync"]

  def self.documentation
    "Pull from remote, then restack."
  end

  def call(*args)
    remote = @stack.config.remote
    if remote.nil?
      if @git.remotes.size == 1
        remote = @git.remotes.first
      elsif @git.remotes.size > 1
        remote = Shell.prompt("Remote to sync with: ", options: @git.remotes)
      else
        self_destruct "No remotes found. Please add a remote."
      end
    end
    puts "Fetching from remote #{remote.cyan}..."
    remote_branches = @git.branches(:remote).map(&:name)
    @git.fetch(remote)
    deleted_branches = remote_branches - @git.branches(:remote).map(&:name)

    @stack.current_stack.each do |branch|
      if deleted_branches.include?("#{@git.remotes.first}/#{branch}")
        if Shell.prompt?("Remote branch #{branch.cyan} was deleted. Delete the local branch?")
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
      else
        if remote_branches.include?("#{remote}/#{branch}")
          @git.pull(remote: @stack.config.remote, remote_branch: branch)
        else
          puts "No remote branch for #{branch.cyan}"
        end
      end

      parent = @git.parent_of(branch)
      next if parent == '' or parent.nil? # We may be updating the root branch, which has no parent

      puts "Rebasing #{branch.cyan} on #{parent.cyan}"
      @git.rebase(branch, parent)
    end

    @stack.refresh
  end
end
