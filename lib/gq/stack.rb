# frozen_string_literal: true
require 'toml'
require_relative 'shell'
require_relative 'config'

# Require all commands
Dir.glob(File.dirname(__FILE__) + '/commands/*.rb').each { |f| require f }

class Stack
  extend Forwardable
  attr_reader :config
  COMMANDS = [
    AddBranch,
    Commit,
    Config,
    Down,
    Init,
    Log,
    Restack,
    Sync,
    Submit,
    Up,
  ]

  def initialize(config, git: Git)
    @config = config
    @git = git
  end

  def refresh(existing_config=@config)
    new_config = StackConfig.from_git
    if existing_config
      # Clone the user settings
      new_config.root_branch = existing_config.root_branch
      new_config.remote = existing_config.remote
      new_config.code_review_tool = existing_config.code_review_tool
    end
    StackFile.save(new_config)
    @config = new_config
  end

  def_delegator :config, :branches

  def add_branch(branch, parent = nil)
    self_destruct "Branch already exists: #{branch.name}" if branches.key?(branch.name)
    branches[branch.name] = StackBranch.new(name: branch.name, sha: branch.sha, parent: parent)
    # TODO: link_parents in @config
    StackFile.save(@branches)
    branches[branch.name]
  end

  def root
    branches[@config.root_branch]
  end

  def current_branch
    if branches.include? @git.current_branch.name
      branches[@git.current_branch.name]
    else
      StackBranch.new(name: @git.current_branch.name, sha: @git.current_branch.sha, parent: @git.parent_of(@git.current_branch.name))
    end
  end

  def current_stack
    stack_for(current_branch.name)
  end

  def stack_for(branch_name)
    stk = [branch_name]
    branch = branches[branch_name]

    while branch.parent && !branch.parent.empty? && branch.parent != @config.root_branch
      stk << branch.parent
      parent = branch.parent
      branch = branches[parent]
      self_destruct "Branch #{parent} not found in stack!" if branch.nil?
    end
    stk.reverse
  end

  def roots
    ([@config.root_branch] +
      branches
        .values
        .select { |b| b.parent.nil? || b.parent.empty? }
        .map(&:name))
      .uniq
  end

  def stacks(root = @config.root_branch)
    # Each unique path from root -> leaf is a stack.
    dfs([], root, [])
  end

  def to_s
    branches = {}
    stacks.each_with_index do |stack, i|
      stack.each do |branch|
        next if branches.key? branch
        color = @git.current_branch == branch ? :cyan : :green
        branches[branch] = tree("#{branch}".send(color), i, " | ".send(color))
      end
    end

    branches.values.reverse.join("\n")
  end

  def dfs(path, branch, stacks)
    path << branch
    unless branches.include? branch
      puts "Branch #{branch} not in stack!"
    end
    if branches[branch].children.empty?
      stacks << path.dup
    else
      branches[branch].children.each do |child|
        dfs(path, child, stacks)
      end
    end
    stacks
  end

  private
  def method_missing(name, *args)
    COMMANDS.each do |cmd|
      if cmd::COMMAND.include? name.to_s
        return cmd.new(self).call(*args)
      end
    end

    super
  end

  def respond_to_missing?(name, include_private = false)
    COMMANDS.any? { |cmd| cmd::COMMAND.include? name.to_s } || super
  end
end
