# frozen_string_literal: true
require_relative '../shell'
require_relative 'command'

class Sync < Command
  include ResetableCommand

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

    deleted_branches = @stack.branches.keys - @git.branches
    deleted_branches.each(&method(:forget_branch))

    # Refresh the stack
    @stack.refresh if deleted_branches.any?

    puts "Updating branch contents..."
    results = pull_all.zip(@git.branches)
    pulled_branches = results.select { |result, _| result.success? }.map(&:last).map(&:name)

    # Now restack all our branches
    puts "Restacking Branches"
    pulled_branches.each do |branch|
      parent = @git.parent_of(branch)
      unless parent.nil? || parent.empty?
        @git.rebase(branch, parent)
        remove_branch(branch) if @git.commit_diff(parent, branch).empty?
      end
    end
  end

  def pull_all
    remote_branches = @git.branches(:remote).map(&:name)
    to_sync = @stack.roots.map { |root| branches[root] }.compact

    until to_sync.empty?
      branch = to_sync.shift
      to_sync += branch.children.map { |child| branches[child] }
      pull_branch(branch.name, remote_branches)
    end
  end

  protected

  def pull_branch(branch, remote_branches)
    @git.checkout(branch)
    result = if remote_branches.include?("#{@stack.config.remote}/#{branch}")
               @git.pull(remote: @stack.config.remote, remote_branch: branch)
             elsif @git.parent_of(branch) != ''
               if @git.parent_of(branch).start_with?(@stack.config.remote)
                 if Shell.prompt? "#{RED_X} #{branch.cyan}'s remote branch has been deleted. Delete branch?"
                   remove_branch(branch)
                 else
                   ShellResult.new('', '', exit_code: 0)
                 end
               else
                 @git.pull
               end
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

  private

  def forget_branch(branch)
    # This branch was removed from git, but still exists in our config - relink parents
    # Rebase any children
    parent = @stack.branches[branch].parent
    unless parent.nil? || parent.empty?
      @stack.branches[branch].children.each { |child| @git.rebase(child, parent) }
    end
  end

  def remove_branch(branch)
    if Shell.prompt?("Remove merged branch #{branch.cyan}?\n\n#{indent(@git.commit_diff(@git.parent_of(branch), branch).join("\n"))}")
      parent = @git.parent_of(branch)
      # We can't remove the current branch, so checkout the parent if necessary
      @git.checkout(parent) if branch == @git.current_branch.name

      # Rebase any children
      @stack.branches[branch].children.each { |child| @git.rebase(child, parent) }

      # Ok, delete the branch
      @git.delete_branch(branch)
          .tap { |res| puts "Deletion failed\n#{indent(res.output)}" if res.failure? }

      # And refresh our config
      @stack.refresh
      puts "#{CHECKMARK} #{branch.cyan} removed"
    end
  end
end
