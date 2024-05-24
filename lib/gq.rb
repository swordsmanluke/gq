# frozen_string_literal: true

Dir.entries(File.join(File.dirname(__FILE__), 'gq')).each do |file|
  if file.end_with?('.rb')
    require_relative "gq/#{file}"
  end
end

module Gq
  USAGE = <<~USAGE
    Usage:
       gq <git command> | <gq command>

       gq commands:
  USAGE

  class Gq
    attr_reader :git, :stack

    def initialize
      @git = Git
      stack_config = if ::StackFile.exists?
                       ::StackConfig.from_toml_file(::StackFile.config_file_path)
                     else
                       ::StackConfig.from_git
                     end
      @stack = Stack.new(stack_config)
      @stack.refresh if ::StackFile.exists? # Refresh from git, if config file exists - just to sync us up again.
    end

    def run
      self_destruct "not in a git repository" unless git.in_git_repo
      self_destruct usage_string if ARGV.size < 1

      cmd = ARGV.shift
      self_destruct 'gq has not been initialized - please run gq init' unless ::StackFile.exists? or cmd == "init"

      if stack.respond_to?(cmd)
        stack.send(cmd, *ARGV)
      else
        self_destruct "unknown command #{cmd}\n#{usage_string}"
      end
    end

    def usage_string
      lj = ::Stack::COMMANDS.map { |cmd| cmd::COMMAND.join(", ").length }.max + 5
      commands = ::Stack::COMMANDS
                   .map { |cmd| [cmd::COMMAND.join(", "), cmd.documentation] }
                   .map { |(shortcut, doc)| tree(shortcut.ljust(lj) + doc, 3) }
                   .join("\n")

      USAGE + commands
    end
  end
end
