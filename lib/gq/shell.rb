# Shell functions for ruby
require 'open3'

def self_destruct(msg)
  puts msg
  exit 1
end

def red(string)
  "\e[31m#{string}\e[0m"
end

def green(string)
  "\e[32m#{string}\e[0m"
end

def yellow(string)
  "\e[33m#{string}\e[0m"
end

module Gq
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

def bash(command)
  Gq::ShellResult.new(*Open3.capture3(command))
end
