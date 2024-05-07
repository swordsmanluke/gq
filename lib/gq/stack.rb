# frozen_string_literal: true
require_relative 'git'
require 'toml'

module Gq
  StackNode = Struct.new(:name, :head, :parent, :children) do
    def initialize(branch_name, head, parent=nil, children=[])
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
    attr_reader :git, :root

    def initialize(git_client=::Gq::Git)
      @git = git_client
      @root = nil
      @branches = {}
    end

    def config_file_path
      "#{git.root_dir}/.gq/stack.toml"
    end

    def exists?
      File.exist? config_file_path
    end

    def load_file
      self_destruct "No stack config found - have you run `gq init`?" unless exists?
      load_toml(File.read(config_file_path))
    end

    def load_toml(stack_str)
      toml_data = TOML::Parser.new(stack_str).parsed
      create_branches(toml_data)
      link_parents
      @root = @branches.values.find { |b| b.parent.empty? }
    end

    def initialize_stack
      self_destruct "Already initialized" if @file.exists?

      add_branch(git.current_branch)
    end

    def add_branch(branch_name, parent=nil)
      @branches[branch_name] = StackNode.new(branch_name, branch_name, parent)
      save!
    end

    def create_branch(new_branch)
      parent = git.current_branch
      git.new_branch(new_branch)
      add_branch(new_branch, parent)
    end

    def up
      # Move away from the root, from the current node to a child
    end

    def down
      # Move toward the root
    end

    def save!
      nodes = [@root]
      @file.open("w") do |f|
        while nodes.any?
          node = nodes.shift
          f.write(node.to_toml)
          f.write("\n\n")
          nodes += node.children
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
        @branches[bn] = StackNode.new(bn, attrs['head'], attrs['parent'])
      end
    end
  end
end