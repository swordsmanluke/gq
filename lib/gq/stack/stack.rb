# frozen_string_literal: true
require 'toml'
require_relative 'node'
require_relative '../shell'
require_relative 'up'
require_relative 'down'
require_relative 'log'
require_relative 'init'
require_relative 'add_branch'
require_relative 'commit'

module Gq::Stack
  class Stack
    attr_reader :branches

    COMMANDS = [
      Init, Up, Down, Log, AddBranch, Commit
    ]

    def initialize(branches={}, git: ::Gq::Git)
      @branches = branches
      @git = git
    end

    def self.from_config
      puts "Reloading from local config..."
      new(StackFile.load_config_file)
    end

    def self.refresh(git=::Gq::Git)
      puts "Reloading from local git..."
      # Read branches from git and rebuild the stack, based on the current branches
      branches = {}
      git.branches.each do |branch|
        branches[branch.name] = Gq::Stack::Node.new(branch.name, branch.sha, parent: git.parent_of(branch.name))
      end
      branches = link_parents(branches)

      StackFile.save(branches)

      new(branches)
    end

    def current_branch
      branches[@git.current_branch.name]
    end

    def add_branch(branch, parent = nil)
      self_destruct "Branch already exists: #{branch.name}" if @branches.key?(branch.name)
      @branches[branch.name] = Node.new(branch.name, branch.sha, parent: parent&.name)
      StackFile.save(@branches)
      @branches[branch.name]
    end

    private
    def method_missing(name, *args)
      COMMANDS.each do |cmd|
        return cmd.new(self).call(*args) if cmd::COMMAND.include? name.to_s
      end

      super
    end

    def respond_to_missing?(name, include_private = false)
      COMMANDS.any? { |cmd| cmd::COMMAND.include? name.to_s } || super
    end

    private
    def link_parents(branches)
      puts"linking parents...(1)"
      branches.values.each do |branch|
        next if branch.parent.nil? || branch.parent.empty?
        branches[branch.parent].children << branch.name
      end

      puts "Parents to children: #{branches.values.map { |b| [b.name, b.children] }.to_h}"

      branches
    end

  end

  class StackFile
    class << self

      def config_file_path
        git = ::Gq::Git
        "#{git.root_dir}/.gq/stack.toml"
      end

      def exists?
        File.exist? config_file_path
      end

      def load_config_file
        self_destruct "1. No stack config found - have you run `gq init`?" unless exists?
        load_toml(File.read(config_file_path))
      end

      def load_toml(stack_str)
        toml_data = TOML::Parser.new(stack_str).parsed
        load_stack_nodes(toml_data)
      end

      def save(branches)
        nodes = branches.values

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

      def load_stack_nodes(toml_data)
        branches = {}
        git = ::Gq::Git

        toml_data.each do |bn, attrs|
          if git.branches.map(&:name).include? bn
            branches[bn] = Node.new(bn, attrs['head'], parent: attrs['parent'])
          else
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
end
