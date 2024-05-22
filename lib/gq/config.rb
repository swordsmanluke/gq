# frozen_string_literal: true
require 'fileutils'

class StackConfig
  # These always come from config file or git
  attr_reader :branches, :version
  # These are set by the user, so we need to be able to update them
  attr_accessor :root_branch, :remote, :code_review_tool
  VERSION = 1

  def initialize(branches={}, **attrs)
    attrs.transform_keys!(&:to_sym)

    @branches = branches
    @version = attrs[:version] || VERSION

    @root_branch = attrs[:root_branch]
    @remote = attrs[:remote]
    @code_review_tool = attrs[:code_review_tool]

    link_parents
  end

  def self.from_git(git=Git)
    # Read branches from git and rebuild the commands, based on the current branches
    branches = {}
    git.branches.each do |branch|
      branches[branch.name] = StackBranch.new(name: branch.name, sha: branch.sha, parent: git.parent_of(branch.name))
    end
    new(branches)
  end

  def self.from_toml_file(file)
    # VERSION 1 parser
    config_hash = file
                    .then { File.read _1 }
                    .then { TOML::Parser.new(_1) }
                    .then { _1.parsed }

    branches = config_hash
                 .then { _1['branches'] }
                 .map { |branch| StackBranch.new(**branch) }
                 .map { |branch| [branch.name, branch] }
                 .to_h

    new(branches.to_h,
        version: config_hash['version'],
        root_branch: config_hash['root_branch'],
        remote: config_hash['remote'],
        code_review_tool: config_hash['code_review_tool'])
  end

  def delete_branch(branch_name)
    new_parent = @branches[branch_name].parent
    @branches[branch_name].children.each do |child|
      # Reparent all the children of the branch we're deleting
      @branches[child].parent = new_parent
    end

    @branches.delete(branch_name)
    @branches[new_parent]&.children&.delete(branch_name)
  end

  def to_h
    { version: 1,
      root_branch: @root_branch,
      remote: @remote,
      code_review_tool: @code_review_tool,
      branches: @branches.values.map(&:to_h) }
  end

  private

  def link_parents
    dirty = false
    branches.values.each do |branch|
      next if branch.parent.nil? || branch.parent.empty?
      parent = branches[branch.parent]
      while parent.nil?
        Shell.prompt "Parent Branch #{branch.parent.cyan} has been deleted - what should #{branch.name.cyan}'s new parent be?", options: @branches.keys do |new_parent|
          branch.parent = new_parent
          parent = branches[new_parent]
          @git.track(branch.name, new_parent)
        end
      end
      parent.children << branch.name
    end
    StackFile.save(self) if dirty
    nil
  end
end

class StackBranch
  attr_accessor :name, :sha, :parent, :children
  def initialize(**attrs)
    attrs = attrs.transform_keys(&:to_sym)
    @name = attrs[:name]
    @sha = attrs[:sha]
    @parent = attrs[:parent]
    @children = []
  end

  def add_child(child)
    @children << child
  end

  def to_h
    { name: @name, sha: @sha, parent: @parent }
  end
end

class StackFile
  class << self
    BASE_DIR = "#{Dir.home}/.config/gq"
    def config_file_path
      git = Git
      project_name = git.root_dir.split('/').last
      File.join [BASE_DIR, project_name, git.root_dir,"stack.toml"]
    end

    def exists?
      File.exist? config_file_path
    end

    def load_config_file
      self_destruct "1. No commands config found - have you run `gq init`?" unless exists?
      load_toml(File.read(config_file_path))
    end

    def load_toml(stack_str)
      toml_data = TOML::Parser.new(stack_str).parsed
      load_stack_nodes(toml_data)
    end

    def save(config)
      FileUtils.mkdir_p(File.dirname(config_file_path)) unless Dir.exist? File.dirname(config_file_path)

      File.open(config_file_path, "w") do |f|
        f.write(TOML::Generator.new(config.to_h).body)
      end
    end

    private

    def load_stack_nodes(toml_data)
      branches = {}
      git = Git

      toml_data.each do |bn, attrs|
        branches[bn] = Node.new(bn, attrs['head'], parent: attrs['parent'])
        unless git.branches.map(&:name).include? bn
          puts "#{bn} is missing. Did you manually delete it?"
        end
      end

      branches.values.each do |branch|
        branches[branch.parent]&.tap { |p| p.children << branch.name }
      end

      branches
    end
  end
end