# frozen_string_literal: true

require "spec_helper"

RSpec.describe Gq::Stack do
  context 'when parsing a toml file' do
    subject(:stack) { Gq::Stack.new.tap{_1.load_file('spec/fixtures/simple_stack.toml')} }

    it 'identifies the root' do
      expect(stack.root.name).to eq('master')
    end

    it 'identifies the path from the root to branch1.2'do
      # Traverse the stack to find branch1.2, then identify the path from the root.
      # It should be master -> branch1 -> branch1.1 -> branch1.2
      expect(path_to(stack.root, 'branch1_2')).to eq(['master', 'branch1', 'branch1_1'])
    end

    it 'identifies the path from the root to branch2'
  end

  def path_to(node, branch_name, path=[])
    return nil if node.nil?
    # DFS traversal until we find the branch
    return path if node.name == branch_name

    path << node.name
    node.children.each do |child|
      p = path_to(child, branch_name, path)
      return p unless p.nil?
    end

    return nil # dead end
  end
end
