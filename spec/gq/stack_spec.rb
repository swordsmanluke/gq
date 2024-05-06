# frozen_string_literal: true

require "spec_helper"

RSpec.describe Gq::Stack do
  context 'when parsing a toml file' do
    subject(:stack) { Gq::Stack.new.tap { _1.load_file('spec/fixtures/simple_stack.toml') } }

    it 'identifies the root' do
      expect(stack.root.name).to eq('master')
    end

    it 'identifies the path from the root to branch1_2' do
      expect(path_to(stack.root, 'branch1_2')).to eq(['master', 'branch1', 'branch1_1', 'branch1_2'])
    end

    it 'identifies the path from the root to branch2' do
      expect(path_to(stack.root, 'branch2')).to eq(['master', 'branch2'])
    end
  end

  def path_to(node, branch_name, path=['master'])
    puts "Exploring: #{path.join(' -> ')}"
    # DFS traversal until we find the branch
    return path if node.name == branch_name

    node.children.each do |child|
      path_to(child, branch_name, path + [child.name])&.tap { return _1}
    end

    nil
  end
end
