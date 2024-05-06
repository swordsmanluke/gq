# frozen_string_literal: true
require 'gq/git'
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

    def load_file(toml_file_path)
      self_destruct "No stack file found at #{toml_file_path}" unless File.exists? toml_file_path

      load_toml(File.read(toml_file_path))
    end

    def load_toml(stack_str)
      toml_data = TOML::Parser.new(stack_str).parsed
      create_branches(toml_data)
      link_parents
      @root = @branches.values.find { |b| b.parent.empty? }
    end

    def checkout(branch_node)
      git.checkout(branch_node.branch_name)
    end

    def up
      # Move away from the root, from the current node to a child
    end

    def down
      # Move toward the root
    end

    def save!(toml_file_path)
      nodes = [@root]
      File.open(toml_file_path, "w") do |f|
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