# frozen_string_literal: true

class Command
  COMMAND = ["command", "cmd"]

  def initialize(stack, git=Git)
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

module ResetableCommand
  def self.included(base)
    wrapped_call = Proc.new do |*args|
      og_call = base.method(:call)
      cb = current_branch.name
      begin
        og_call.(*args)
      ensure
        puts "Done. Switching back to #{cb.cyan}..."
        @git.checkout cb
      end
    end

    base.define_method(:call, &wrapped_call)
  end
end
