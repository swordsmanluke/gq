# frozen_string_literal: true

require_relative "gq/version"
require_relative 'gq/shell'
require_relative 'gq/stack'

module Gq
  USAGE = """
Usage:
   gq <git command> | <gq command>

   gq commands:
     init:     initialize a new gq stack - run once in a git repo

     create:   create and switch to a new branch

     commit:   create a new commit

     checkout: switch to a different branch

     log:      show the current commit stack

     update:   pull root, then rebase everything on the remote changes

     right:    move away from root

     left:     move toward root

     switch:   change the parent of the current branch and rebase this branch and its descendents on the parent

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
      self_destruct 'gq has not been initialized - please run gq init' unless stack.exists? or cmd == "init"

      case cmd
      when "init"
        stack.initialize_stack
      when "cc", "commit" # Commit
        stack.commit(ARGV)
      when "bc", "create" # Create branch
        stack.create_branch(ARGV.shift)
      when "log"
        stack.stack.each do |(bn, diff)|
          puts "#{bn}:\n#{diff}"
        end
      when "up"
        stack.up
      when "down"
        stack.down
      when "sync"
        self_destruct "Not implemented yet!"
      when "move"
        self_destruct "Not implemented yet!"
      else
        puts "unknown command #{cmd}"
      end
    end
  end
end

Gq::Gq.new.run
