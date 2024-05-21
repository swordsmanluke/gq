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
    remote_branches = @git.branches(:remote).map(&:name)
    @git.fetch(remote)

    puts "Updating branch contents..."
    results = pull_all.zip(@git.branches)
    results.each do |result, branch|
      if result.success?
        puts "#{CHECKMARK} #{branch.cyan}"
      else
        puts "#{RED_X} #{branch.cyan}"
        puts indent(result.output)
      end
    end

    pulled_branches = results.select { |result, _| result.success? }.map(&:last).map(&:name)

    # Now restack all our branches
    puts "Restacking Branches"
    pulled_branches.each do |branch|
      parent = @git.parent_of(branch)
      @git.rebase(branch, parent)
    end
  end

  def pull_all
    remote_branches = @git.branches(:remote).map(&:name)
    @git.branches(:local).map(&:name).each do |branch|
      if remote_branches.include?("#{@git.remotes.first}/#{branch}")
        @git.pull(remote: @stack.config.remote, remote_branch: branch)
      else
        @git.pull
      end
    end
  end
end
