# frozen_string_literal: true
require_relative '../shell'
require_relative 'command'

class Sync < Command
  include ResetableCommand

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
    @git.fetch(remote)

    deleted_branches = @stack.branches.keys - @git.branches
    deleted_branches.each(&method(:forget_branch))

    # Refresh the stack state
    @stack.refresh if deleted_branches.any?

    puts "Updating branch contents..."
    pull_all
      .each { puts format_result(_1) }
      .select { _1[:success] }
      .map {  [_1[:branch], @git.parent_of(_1[:branch])] }
      .select { |(branch, parent)| @git.diff(parent, branch).split("\n").reject(&:empty?).empty? }
      .each { |(branch, _parent)| remove_branch(branch) }
  end

  def pull_all
    remote_branches = @git.branches(:remote).map(&:name)
    to_sync = @stack.roots.map { |root| @stack.branches[root] }.compact
    [].tap do |results|
      until to_sync.empty?
        branch = to_sync.shift
        to_sync += branch.children.map { |child| @stack.branches[child] }
        matching_remote_branches = remote_branches.filter { |rb| rb == "#{@stack.config.remote}/#{branch.name}" }
        res = sync_branch(branch.name, matching_remote_branches)
        res = rebase_branch(branch.name) if res[:success]
        results << res
      end
    end
  end

  protected

  def format_result(result)
    mark = result[:success] ? CHECKMARK : RED_X
    [
      "#{mark} #{result[:branch].cyan}",
      indent(result[:output])
    ].reject(&:empty?).join("\n")
  end

  def is_local_branch?(branch)
    return false if branch.nil? || branch.empty?

    @git.branches(:local).map(&:name).include?(branch)
  end

  def sync_branch(branch, remote_branches)
    @git.checkout(branch)
    # Sync remote content first
    remote_branches.each { @git.pull(@stack.config.remote, branch) }
    # Then sync with the local parent if present
    result = @git.pull if is_local_branch?(@git.parent_of(branch))

    if result.nil? || result.success?
      { success: true, branch: branch }
    else
      { success: false, branch: branch, output: result.output }
    end
  end

  def rebase_branch(branch, onto: nil)
    res = @git.rebase(branch, onto || @git.parent_of(branch))
    if res.nil? || res.success?
      { success: true, branch: branch }
    else
      { success: false, branch: branch, output: res.output }
    end
  end

  private

  def forget_branch(branch)
    # This branch was removed from git, but still exists in our config - relink parents
    # Rebase any children
    parent = @stack.branches[branch].parent
    unless parent.nil? || parent.empty?
      @stack.branches[branch].children.each { |child| @git.rebase(child) }
    end
  end

  def remove_branch(branch)
    return if branch == @stack.root.name
    
    if Shell.prompt?("Remove merged branch #{branch.cyan}?")
      parent = @git.parent_of(branch)
      # We can't remove the current branch, so checkout the parent if necessary
      @git.checkout(parent) if branch == @git.current_branch.name

      # Update the children's tracking branch
      @stack.branches[branch].children.each { |child| @git.track(child, parent) }

      # Ok, delete the branch
      @git.delete_branch(branch)
          .tap { |res| puts "Deletion failed\n#{indent(res.output)}" if res.failure? }

      # And refresh our config
      @stack.refresh
      puts "#{CHECKMARK} #{branch.cyan} removed"
    end
  end
end
