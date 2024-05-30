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

def grey(string)
  string.grey
end

def gold(string)
  string.gold
end

def bright_yellow(string)
  string.bright_yellow
end

def bright_white(string)
  string.bright_white
end

def magenta(string)
  string.magenta
end

def bright_magenta(string)
  string.bright_magenta
end

def orange(string)
  string.orange
end

def lime(string)
  string.lime
end

def pink(string)
  string.pink
end

def blue(string)
  string.blue
end

def tree(string, depth, fill = "  ")
  return string unless depth > 0

  indent(string, fill * depth)
end

def indent(string, fill = "  ")
  return "" if string.nil?
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

  def grey
    "\e[90m#{self}\e[0m"
  end

  def bright_white
    "\e[97m#{self}\e[0m"
  end

  def magenta
    "\e[35m#{self}\e[0m"
  end

  def bright_magenta
    "\e[95m#{self}\e[0m"
  end

  def orange
    "\e[38;5;208m#{self}\e[0m"
  end

  def lime
    "\e[38;5;154m#{self}\e[0m"
  end

  def pink
    "\e[38;5;206m#{self}\e[0m"
  end

  def blue
    "\e[38;5;75m#{self}\e[0m"
  end

  def gold
    "\e[38;5;220m#{self}\e[0m"
  end
end

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

    if flags.include?(:secret)
      message = "#{message} (hidden)"
      args << "--password"
    end

    args << "--placeholder '#{placeholder}'" if placeholder

    cmd = "gum #{mode} #{args.join ' '}".chomp

    puts message
    `#{cmd}`
      .chomp
      .tap { |val| yield val if block_given? }
  end

  def self.prompt?(message, *flags, options: ['y', 'n'], selected: 'y')
    Shell.prompt(message, *flags, options: options) == selected
  end
end

class ShellResult
  attr_reader :stdout, :stderr, :exit_code

  def initialize(stdout, stderr, status=nil, exit_code: nil)
    @stdout = stdout
    @stderr = stderr
    @exit_code = status&.exitstatus || exit_code || 0
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

def bash(command, do_fn: ->(_) {}, or_fn: ->(_) {})
  ShellResult.new(*Open3.capture3(command)).tap do|res|
    if res.success?
      do_fn.call(res)
    else
      puts "#{`pwd`.chomp}$ #{command}\n#{indent(res.output)}"
      or_fn.call(res)
    end
  end
end