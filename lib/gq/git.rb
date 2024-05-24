# frozen_string_literal: true
require_relative "shell"
require_relative 'git/git'

class Git
  include GitBase

  class << self
    ### Actions
    def temp_branch(parent = current_branch, slug = nil)
      self_destruct("Not in a git repository") unless in_git_repo
      raise "no block given to temp_branch" unless block_given?

      branchname = ["temp", slug, SecureRandom.hex(4)].compact.join("-")
      current_branch do
        begin
          # Create the branch, but don't switch to it or nothin'
          bash("git checkout -b #{branchname} -t #{parent}")
          yield branchname
        ensure
          delete_branch(branchname)
        end
      end
    end

    def pull(*args, **kwargs)
      git("pull", *args, **kwargs)
    end

    def fetch(remote = nil)
      self_destruct("Not in a git repository") unless in_git_repo

      bash("git fetch #{remote} -p", or_fn: -> (res) { self_destruct res.output })
    end

    def checkout(branch_name)
      self_destruct("Not in a git repository") unless in_git_repo
      return if branch_name == current_branch.name

      res = bash("git -c core.hooksPath=/dev/null checkout #{branch_name}")
      self_destruct "Failed to checkout branch: #{red(branch_name)}\n#{res.output}" if res.failure?
      nil
    end

    def ignore(path)
      self_destruct("Not in a git repository") unless in_git_repo

      bash("echo #{path} >> .gitignore") unless File.readlines(".gitignore").any? { |line| line.chomp == path }
    end

    def new_branch(branch_name, tracking: nil)
      self_destruct("Not in a git repository") unless in_git_repo

      args = ["-b #{branch_name}"]
      args << "--track #{tracking}" if tracking

      bash("git checkout #{args.join(" ")}")
        .tap { |res| self_destruct("Failed to create branch: #{red(branch_name)}\n#{res.output}") if res.failure? }
      current_branch
    end

    def commit(args)
      self_destruct("Not in a git repository") unless in_git_repo
      bash("git commit #{args}")
    end

    def merge(other_branch)
      self_destruct("Not in a git repository") unless in_git_repo
      bash("git merge #{other_branch} --no-edit")
    end

    def push(branch, remote: nil)
      self_destruct("Not in a git repository") unless in_git_repo

      og_branch = current_branch.name
      checkout(branch)
      bash("git -c core.hooksPath=/dev/null push #{remote} #{branch}")
        .tap { checkout og_branch } # Restore the original branch after attempting the push, either success or failure
        .then { self_destruct("Failed to push branch: #{red(branch)}\n#{_1.output}") if _1.failure? }
    end

    def rebase(branch, parent = nil)
      self_destruct("Not in a git repository") unless in_git_repo
      return if branch == parent or parent.nil? or parent.empty?
      current_branch do
        checkout(branch)
        puts "Rebasing #{branch.cyan} onto #{parent.cyan}..."
        res = bash("git -c core.hooksPath=/dev/null rebase #{parent}")
        bash("git -c core.hooksPath=/dev/null rebase --abort") if res.failure?
        return res
      end
    end

    def rename_branch(old_name, new_name)
      self_destruct("Not in a git repository") unless in_git_repo
      puts "Renaming #{old_name.cyan} to #{new_name.cyan}..."
      checkout(old_name)
      return bash("git branch -m #{new_name}")
    end

    def cherrypick(sha)
      self_destruct("Not in a git repository") unless in_git_repo
      puts indent("cherrypicking #{sha.cyan}...")

      bash("git cherry-pick #{sha} --no-edit")
    end

    def delete_branch(branch)
      self_destruct("Not in a git repository") unless in_git_repo
      bash("git branch -d #{branch}")
    end

    def track(child, parent)
      self_destruct("Not in a git repository") unless in_git_repo
      og_branch = if current_branch != child
                    current_branch
                    checkout(child)
                  end

      bash("git branch --set-upstream-to=#{parent}")
        .tap { checkout(og_branch) if og_branch }
        .tap { self_destruct("Failed to track branch: #{red(child)}") if _1.failure? }
    end

    ### Data

    def in_git_repo
      `git rev-parse --is-inside-work-tree`.strip == "true"
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

      bash("git log #{branch1}..#{branch2} --format=oneline")
        .output
        .split("\n")
        .map { _1.split(" ") }
        .map { [_1.shift, _1.join(" ")] } # Sha, followed by everything else
    end

    def diff(branch1, branch2)
      self_destruct("Not in a git repository") unless in_git_repo
      return [] if branch2.nil?

      bash("git diff #{branch1}..#{branch2}").output
    end

    def current_branch
      self_destruct("Not in a git repository") unless in_git_repo

      name = `git branch --show-current`.chomp
      sha = `git rev-parse --short HEAD`.chomp
      Branch.new(name, sha).tap do |b|
        if block_given?
          begin
            yield b
          ensure
            checkout(b.name)
          end
        end
      end
    end

    def parent_of(branch_name)
      self_destruct("Not in a git repository") unless in_git_repo

      parents[branch_name]
    end

    def branches(type = :local)
      self_destruct("Not in a git repository") unless in_git_repo

      cmd = "git branch --format='%(refname:short) %(objectname:short)'"
      cmd += " -r" if type == :remote

      bash(cmd)
        .stdout
        .split("\n")
        .map { |name_and_hash| Branch.new(*name_and_hash.split(" ")) }
    end

    def remotes
      self_destruct("Not in a git repository") unless in_git_repo
      bash("git remote").stdout.split("\n")
    end

    def remote_url(remote)
      self_destruct("Not in a git repository") unless in_git_repo
      bash("git remote get-url #{remote}").stdout
    end

    def parents
      parent_regex = /\s*(\S+\s+[a-f0-9]+)(\s+\[(.*)\])?\s+(.*)/
      bash("git branch -vv")
        .stdout
        .chomp
        .split("\n")
        .map { |line| parent_regex.match(line) }
        .map { |match| [match[1].split(" ").reject { _1 == "*" }.first, match[3]] }
        .map { |name, parent| [name, extract_parent(parent)] }
        .to_h
    end

    def commits(branch = current_branch.name, count = 10)
      bash("git log -#{count} #{branch}")
        .stdout
        .split(/^commit [a-f0-9]+$/)
        .reject(&:empty?)
    end

    # Helper functions

    def extract_parent(parent)
      return "" if parent.nil? || parent.empty?
      parent.split(":").first
    end
  end
end

class Branch
  attr_reader :name, :sha

  def initialize(name, sha)
    @name = name
    @sha = sha
  end
end
