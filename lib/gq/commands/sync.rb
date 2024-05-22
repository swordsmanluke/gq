# frozen_string_literal: true
require_relative '../shell'
require_relative 'command'

class Sync < Command
  COMMAND = ["sync"]

  CHECKMARK = "\u2713".green
  RED_X = "\u2717".red

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
    @git.fetch(remote)

    puts "Updating branch contents..."
    results = pull_all.zip(@git.branches)
    pulled_branches = results.select { |result, _| result.success? }.map(&:last).map(&:name)

    merged_branches = pulled_branches
      .map { [@git.parent_of(_1), _1] }
      .reject { |parent, _branch| parent.nil? || parent == '' } # Don't delete roots
      .select { |parent, branch| @git.commit_diff(parent, branch).empty? }
      .map(&:last)

    merged_branches.each do |ready_to_remove|
      if Shell.prompt?("Remove merged branch #{ready_to_remove.cyan}?")
        parent = @git.parent_of(ready_to_remove)
        # We can't remove the current branch, so checkout the parent if necessary
        @git.checkout(parent) if ready_to_remove == @git.current_branch.name

        # Rebase any children
        @stack.branches[ready_to_remove].children.each { |child| @git.rebase(child, parent) }

        # Ok, delete the branch
        @git.delete_branch(ready_to_remove)
            .tap {|res| puts "Deletion failed\n#{indent(res.output)}" if res.failure? }

        # And refresh our config
        @stack.refresh
        puts "#{CHECKMARK} #{ready_to_remove.cyan} removed"
      end
    end

    # Now restack all our branches
    puts "Restacking Branches"
    pulled_branches.each do |branch|
      parent = @git.parent_of(branch)
      @git.rebase(branch, parent)
    end
  end

  def pull_all
    remote_branches = @git.branches(:remote).map(&:name)
    @git.branches(:local).map(&:name).map do |branch|
      @git.checkout(branch)
      result = if remote_branches.include?("#{@git.remotes.first}/#{branch}")
                 @git.pull(remote: @stack.config.remote, remote_branch: branch)
               elsif @git.parent_of(branch) != ''
                 @git.pull
               else
                 # No remote branch or no parent, so nothing to pull
                 ShellResult.new('', '', exit_code: 0)
               end

      if result.success?
        puts "#{CHECKMARK} #{branch.cyan}"
      else
        puts "#{RED_X} #{branch.cyan}"
        puts indent(result.output)
      end

      result
    end
  end
end
