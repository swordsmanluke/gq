# frozen_string_literal: true

module Gq
  class Command
    COMMAND = ["command", "cmd"]

    def initialize(stack, git=::Gq::Git)
      @stack = stack
      @git = git
    end

    def self.documentation
      raise NotImplementedError("This method must be implemented in a subclass.")
    end

    def call(*args)
      raise NotImplementedError("This method must be implemented in a subclass.")
    end
  end
end
