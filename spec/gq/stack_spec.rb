# frozen_string_literal: true
require_relative "../../lib/gq/stack"
require "spec_helper"

RSpec.describe Stack do
  let(:git_mock) { double('Git') }
  let(:instance) { described_class.new(StackConfig.from_toml_file('spec/fixtures/simple_stack.toml'), git: git_mock) }
  context 'when parsing a toml file' do
    subject(:stack) { instance }

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

  context 'when determining the current stack' do
    subject(:current_stack) { instance.current_stack }

    before do
      allow(git_mock).to receive(:current_branch).and_return(double(name: 'branch1_2'))
    end

    it 'finds the current stack' do
      expect(current_stack).to eq(['master', 'branch1', 'branch1_1', 'branch1_2'])
    end
  end

  def path_to(node, branch_name, path=['master'])
    # DFS traversal until we find the branch
    return path if node.name == branch_name

    node.children.each do |child|
      child = stack.branches[child]
      path_to(child, branch_name, path + [child.name])&.tap { return _1}
    end

    nil
  end
end
