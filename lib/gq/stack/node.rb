# frozen_string_literal: true

module Gq::Stack
  Node = Struct.new(:name, :head, :parent, :children) do
    def initialize(branch_name, head, parent: nil, children: [])
      super(branch_name, head, parent, children)
    end

    def to_toml
      "[#{name}]\nhead = \"#{head}\"\nparent = \"#{parent}\""
    end
  end
end
