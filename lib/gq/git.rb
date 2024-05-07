# frozen_string_literal: true
require_relative 'shell'

module Gq
  class Git
    class << self
      def in_git_repo
        `git rev-parse --is-inside-work-tree`.strip == 'true'
      end

      def checkout(branch_name)
        self_destruct("Not in a git repository") unless in_git_repo

        res = bash("git checkout #{branch_name}")
        self_destruct("Failed to checkout branch: #{red(branch_name)}\n#{res.output}") if res.failure?
        nil
      end

      def root_dir
        self_destruct("Not in a git repository") unless in_git_repo

        bash("git rev-parse --show-toplevel")
          .tap { |res| self_destruct("Failed to find root directory - are you in a git repository?") if res.failure? }
          .stdout
          .chomp
      end

      def ignore(path)
        self_destruct("Not in a git repository") unless in_git_repo

        bash("echo #{path} >> .gitignore") unless File.readlines(".gitignore").any? { |line| line.chomp == path }
      end

      def current_branch
        self_destruct("Not in a git repository") unless in_git_repo

        name = `git branch --show-current`.chomp
        sha = `git rev-parse --short HEAD`.chomp
        Branch.new(name, sha)
      end

      def new_branch(branch_name)
        self_destruct("Not in a git repository") unless in_git_repo

        parent = current_branch
        bash("git checkout -t #{parent.name} -b #{branch_name}")
          .tap { |res| self_destruct("Failed to create branch: #{red(branch_name)}\n#{res.output}") if res.failure? }
        current_branch
      end

      class Branch
        attr_reader :name, :sha

        def initialize(name, sha)
          @name = name; @sha = sha
        end
      end
    end
  end
end