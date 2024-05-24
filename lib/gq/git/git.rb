# frozen_string_literal: true
require_relative '../shell'
module GitBase
  def self.included(base)
    base.extend(ClassMethods)
  end

  module ClassMethods
    def in_git_repo
      `git rev-parse --is-inside-work-tree`.strip == "true"
    end

    def git(*args, **kwargs)
      self_destruct("Not in a git repository") unless in_git_repo
      no_hooks = kwargs.delete(:no_hooks)

      cmd = "git"
      cmd += " -c core.hooksPath=/dev/null" if no_hooks

      cmd += " #{args.join(' ')}"

      bash(cmd)
    end
  end
end

