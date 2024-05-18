# Shell functions for ruby
require "open3"

def self_destruct(msg)
  puts msg
  exit 1
end

def red(string)
  string.red
end

def green(string)
  string.green
end

def yellow(string)
  string.yellow
end

def cyan(string)
  string.cyan
end

def tree(string, depth, fill = "  ")
  indent(string, fill * depth)
end

def indent(string, fill = "  ")
  string.split("\n").map { fill + _1 }.join("\n")
end

class String
  def red
    "\e[31m#{self}\e[0m"
  end

  def green
    "\e[32m#{self}\e[0m"
  end

  def yellow
    "\e[33m#{self}\e[0m"
  end

  def bright_yellow
    "\e[33;1m#{self}\e[0m"
  end

  def cyan
    "\e[36m#{self}\e[0m"
  end
end

module Gq
  class Shell
    # Helper methods for working with the shell
    def self.prompt(message, *flags, options: nil, placeholder: nil)
      args = []
      mode = if options
               args << options.join(" ")
               "choose"
             elsif flags.include?(:multiline)
               "write"
             else
               "input"
             end

      args << "--placeholder '#{placeholder}'" if placeholder

      cmd = "gum #{mode} #{args.join ' '}".chomp
      puts "> #{cmd}"

      puts message
      `#{cmd}`.chomp
    end
  end

  class ShellResult
    attr_reader :stdout, :stderr, :exit_code

    def initialize(stdout, stderr, status)
      @stdout = stdout
      @stderr = stderr
      @exit_code = status.exitstatus
    end

    def success?
      @exit_code.zero?
    end

    def failure?
      !success?
    end

    def output
      [@stdout, @stderr].join("\n")
    end
  end
end

def bash(command, do_fn: ->(_) {}, or_fn: ->(_) {})
  Gq::ShellResult.new(*Open3.capture3(command)).tap do|res|
    if res.success?
      do_fn.call(res)
    else
      or_fn.call(res)
    end
  end


end

