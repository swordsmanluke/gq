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

      def commit_diff(branch1, branch2)
        self_destruct("Not in a git repository") unless in_git_repo
        return "" if branch2.nil?

        bash("git log #{branch2}..#{branch1} --format=oneline")
          .output
          .split("\n")
          .map { _1.split(" ") }
          .map { [_1.shift, _1.join(" ")]} # Sha, followed by everything else
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

      def parent_of(branch_name)
        self_destruct("Not in a git repository") unless in_git_repo

        parents[branch_name]
      end

      def branches
        self_destruct("Not in a git repository") unless in_git_repo

        bash("git branch --format='%(refname:short) %(objectname:short)'")
          .stdout
          .split("\n")
          .map { |name_and_hash| Branch.new(*name_and_hash.split(" ")) }
      end

      def new_branch(branch_name, tracking: nil)
        self_destruct("Not in a git repository") unless in_git_repo

        args = ["-b #{branch_name}"]
        args << "--track #{tracking}" if tracking

        bash("git checkout #{args.join(' ')}")
          .tap { |res| self_destruct("Failed to create branch: #{red(branch_name)}\n#{res.output}") if res.failure? }
        current_branch
      end

      def commit(args)
        self_destruct("Not in a git repository") unless in_git_repo
        cmd = ["git commit", args].join(' ')
        puts "> #{cmd}"
        `#{cmd}`
      end

      def remotes
        bash("git remote").stdout.split("\n")
      end

      def parents
        bash("git branch -vv")
          .stdout
          .chomp
          .split("\n")
          .map { |line| line.split(' ') }
          .compact
          .map { |name, *rest| name != '*' ? [name, *rest] : rest }
          .map { |name, _, parent| [name, parent[1...-1]] }
          .reject { |_, parent| remotes.any? { parent.start_with?("#{_1}/") }}
          .to_h
      end
    end

    def self.rebase(branch, parent)
      self_destruct("Not in a git repository") unless in_git_repo

      bash("git checkout #{branch}",
           or_fn: -> (_) { self.destruct "Could not checkout #{branch} to rebase on #{parent}." })
      bash("git rebase #{parent}",
           or_fn: -> (_) { self.destruct "Rebase #{branch} -> #{parent} failed. Run git mergetool then git rebase --continue" })
    end

    def self.delete_branch(branch)
      self_destruct("Not in a git repository") unless in_git_repo
      bash("git branch -D #{branch}")
    end
  end

  class Branch
    attr_reader :name, :sha

    def initialize(name, sha)
      @name = name; @sha = sha
    end
  end
end