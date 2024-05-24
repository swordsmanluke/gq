# frozen_string_literal: true
require_relative 'git'

module GitBase
  module Pull
    include GitBase

    def included(base)
      base.extend(ClassMethods)
    end

    module ClassMethods
      def pull(*args, no_hooks: true)
        self.git('pull', *args, no_hooks: no_hooks)
      end
    end
  end
end
