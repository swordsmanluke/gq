# frozen_string_literal: true
require_relative 'git'
require 'toml'

module Gq
  StackNode = Struct.new(:name, :head, :parent, :children) do
    def initialize(branch_name, head, parent = nil, children = [])
      super(branch_name, head, parent, children)
    end

    def add_child(child)
      if child.parent == name
        children << child
        true
      else
        children.any? { |c| c.add_child(child) }
      end
    end

    def to_toml
      "[#{name}]\nhead = \"#{head}\"\nparent = \"#{parent}\""
    end
  end

  class Stack
    attr_reader :git, :branches

    def initialize(git_client = ::Gq::Git)
      @git = git_client
      @branches = {}
    end

    def config_file_path
      "#{git.root_dir}/.gq/stack.toml"
    end

    def exists?
      File.exist? config_file_path
    end

    def stack
      node = branches[git.current_branch.name]
      [[node.name, git.commit_diff(node.name, node.parent)]].tap do |stk|
        while(node = branches[node.parent])
          stk << [node.name, git.commit_diff(node.name, node.parent)]
        end
      end
    end

    def commit(commit_args)
      commit_args.map! { |arg| arg.include?(' ') ? "\"#{arg}\"" : arg }

      unless commit_args.include? '-m' or commit_args.include? '--message' or commit_args.include? '-am'
        commit_args << '-m'
        commit_args << Shell.prompt("Commit message", :multiline, placeholder: "Enter your commit message, CTRL-D to finish.")
                            .then { |msg| "\"#{msg}\"" } # quote the message
      end
      @git.commit(commit_args.join(' '))
    end

    def load_file
      self_destruct "1. No stack config found - have you run `gq init`?" unless exists?
      load_toml(File.read(config_file_path))
    end

    def load_toml(stack_str)
      toml_data = TOML::Parser.new(stack_str).parsed
      create_branches(toml_data)
      link_parents
    end

    def initialize_stack
      self_destruct "Already initialized" if exists?

      add_branch(git.current_branch)
      git.ignore('.gq/stack.toml')
    end

    def add_branch(branch, parent = nil)
      self_destruct "Branch already exists: #{branch.name}" if @branches.key?(branch.name)

      @branches[branch.name] = StackNode.new(branch.name, branch.sha, parent&.name)
      save!
    end

    def create_branch(new_branch)
      parent = git.current_branch
      new_br = git.new_branch(new_branch)
      add_branch(new_br, parent)
    end

    def up
      # Move away from the root, from the current node to a child
      git.checkout(@branches[git.current_branch.name].children.first.name)
    end

    def down
      git.checkout(@branches[git.current_branch.name].parent)
    end

    def save!
      nodes = @branches.values
      Dir.mkdir(File.dirname(config_file_path)) unless Dir.exist? File.dirname(config_file_path)
      File.open(config_file_path, "w") do |f|
        while nodes.any?
          node = nodes.shift
          f.write(node.to_toml)
          f.write("\n\n")
        end
      end
    end

    private

    def link_parents
      @branches.values.each do |branch|
        next if branch.parent.nil? || branch.parent.empty?
        # TODO: If a parent branch is missing... what do?
        @branches[branch.parent].add_child(branch)
      end
    end

    def create_branches(toml_data)
      toml_data.each do |bn, attrs|
        if git.branches.include? bn
          @branches[bn] = StackNode.new(bn, attrs['head'], attrs['parent'])
        else
          puts "#{bn} is missing. Did you manually delete it?"
        end
      end

      @branches.values.each do |branch|
        @branches[branch.parent]&.tap { |p| p.add_child(branch) }
      end
    end
  end
end