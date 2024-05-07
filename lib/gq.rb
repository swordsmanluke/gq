# frozen_string_literal: true

require_relative "gq/version"
require_relative 'gq/shell'
require_relative 'gq/stack'

module Gq
  USAGE = """
Usage:
   gq <git command> | <gq command>

   gq commands:
     create <bn>: creates and switches to a new branch named <bn>

     up:     move away from the root

     down:   move toward the root

     sync:   pull root, then restack everything on the current stack

     move:   change the parent of the current branch and rebase this branch and its descendents

     squash: move the current branch's commits to its parent and delete this branch

  These override existing git commands:
     commit:                   create a new git commit

     checkout [bn]:            check out a branch - if no branch name provided, provides a UI for the checkout

     push [branch|down|stack]: push selected branch(es) to the repo. Defaults to `stack`
       * branch: Push just the current branch to `origin`
       * down:   Push the current branch and all modifications below it
       * stack:  Push the entirety of the current stack, including up-stack changes
"""

  class Gq
    attr_reader :git, :stack

    def initialize
      @git = ::Gq::Git
      @stack = ::Gq::Stack.new(git)
      @stack.load_file if @stack.exists?
    end

    def run
      self_destruct "not in a git repository" unless git.in_git_repo
      self_destruct USAGE if ARGV.size < 1

      cmd = ARGV.shift
      puts "Operation: #{cmd}"
      self_destruct 'gq has not been initialized - please run gq init' unless stack.exists? or cmd == "init"

      case cmd
      when "init"
        stack.initialize_stack
      else
        puts "unknown command #{cmd}"
      end
    end

  end
end

Gq::Gq.new.run
