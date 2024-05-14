# frozen_string_literal: true

require_relative "gq/version"
require_relative 'gq/shell'
require_relative 'gq/stack/stack'
require_relative 'gq/git'

module Gq
  USAGE = """
Usage:
   gq <git command> | <gq command>

   gq commands:
"""

  class Gq
    attr_reader :git, :stack

    def initialize
      @git = ::Gq::Git
      @stack = ::Gq::Stack::Stack.new(git)
      @stack = ::Gq::Stack::Stack.from_config if ::Gq::Stack::StackFile.exists?
    end

    def run
      self_destruct "not in a git repository" unless git.in_git_repo
      self_destruct USAGE if ARGV.size < 1

      cmd = ARGV.shift
      self_destruct 'gq has not been initialized - please run gq init' unless ::Gq::Stack::StackFile.exists? or cmd == "init"

      lj = ::Gq::Stack::Stack::COMMANDS.map { |cmd| cmd::COMMAND.join(", ").length }.max + 5

      commands = ::Gq::Stack::Stack::COMMANDS
                .map { |cmd| "      #{(cmd::COMMAND.join(", ")+":").ljust(lj)}#{cmd.documentation}" }
                .join("\n")

      if stack.respond_to?(cmd)
        stack.send(cmd, *ARGV)
      else
        self_destruct "unknown command #{cmd}\n#{USAGE}#{commands}"
      end
    end
  end
end

Gq::Gq.new.run
