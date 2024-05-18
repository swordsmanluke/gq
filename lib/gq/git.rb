# frozen_string_literal: true
require_relative 'shell'

module Gq
  class Git
    class << self
      def in_git_repo
        `git rev-parse --is-inside-work-tree`.strip == 'true'
      end

      def pull(remote: nil, remote_branch: nil)
        self_destruct("Not in a git repository") unless in_git_repo
        if remote && remote_branch
          cmd = "git pull #{remote} #{remote_branch}"
        else
          cmd = "git pull"
        end

        bash(cmd, or_fn: -> (res) { self_destruct res.output })
      end

      def fetch
        self_destruct("Not in a git repository") unless in_git_repo

        bash("git fetch", or_fn: -> (res) { self_destruct res.output })
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
        return [] if branch2.nil?

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

      def branches(type=:local)
        self_destruct("Not in a git repository") unless in_git_repo

        cmd = "git branch --format='%(refname:short) %(objectname:short)'"
        cmd += " -r" if type == :remote

        bash(cmd)
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

      def remote_url(remote)
        bash("git remote get-url #{remote}").stdout
      end

      def push(branch, remote: nil)
        self_destruct("Not in a git repository") unless in_git_repo

        og_branch = current_branch.name
        checkout(branch)
        bash("git push #{remote} #{branch}")
          .tap { checkout og_branch }  # Restore the original branch after attempting the push, either success or failure
          .then { self_destruct("Failed to push branch: #{red(branch)}\n#{_1.output}") if _1.failure? }
      end

      def parents
        parent_regex = /(.*\s+[a-f0-9]+)(\s+\[(.*)\])?\s+(.*)/
        bash("git branch -vv")
          .stdout
          .chomp
          .split("\n")
          .map { |line| parent_regex.match(line) }
          .map { |match| [match[1].split(' ').reject{_1==?*}.first, match[3]] }
          .map { |name, parent| [name, extract_parent(parent)] }
          .reject { |_, parent| remotes.any? { parent.start_with?("#{_1}/") }}
          .to_h
      end

      def commits(branch=current_branch.name, count=10)
        bash("git log -#{count} #{branch}")
          .stdout
          .split(/^commit [a-f0-9]+$/)
          .reject { _1.empty? }
      end

      private

      def extract_parent(parent)
        return "" if parent.nil? or parent.empty?
        parent.split(":").first
      end
    end

    def self.rebase(branch, parent)
      self_destruct("Not in a git repository") unless in_git_repo

      bash("git checkout #{branch}",
           or_fn: -> (_) { self_destruct "Could not checkout #{branch} to rebase on #{parent}." })
      bash("git rebase #{parent}",
           or_fn: -> (_) { self_destruct "Rebase #{branch} -> #{parent} failed. Run git mergetool then git rebase --continue" })
    end

    def self.delete_branch(branch)
      self_destruct("Not in a git repository") unless in_git_repo
      bash("git branch -D #{branch}")
    end

    def self.track(child, parent)
      self_destruct("Not in a git repository") unless in_git_repo
      og_branch = if current_branch != child
                    current_branch
                    checkout(child)
                  else
                    nil
                  end

      bash("git branch --set-upstream-to=#{parent}")
        .tap { checkout(og_branch) if og_branch }
        .tap { self_destruct("Failed to track branch: #{red(child)}") if _1.failure? }
    end
  end

  class Branch
    attr_reader :name, :sha

    def initialize(name, sha)
      @name = name; @sha = sha
    end
  end
end