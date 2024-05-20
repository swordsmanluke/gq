# frozen_string_literal: true

require_relative "../../lib/gq/config"
require_relative '../spec_helper'

RSpec.describe StackConfig do
  let(:branches) do
    {
      'master' => StackBranch.new(name: 'master', sha: '123456'),
      'feature' => StackBranch.new(name: 'feature', sha: 'abcdef', parent: 'master'),
      'bugfix' => StackBranch.new(name: 'bugfix', sha: 'fedcba', parent: 'feature'),
      'hotfix' => StackBranch.new(name: 'hotfix', sha: '654321', parent: 'master')
    }
  end

  subject { described_class.new(branches) }

  it 'creates a new instance' do
    expect(subject).to be_a StackConfig
  end

  it 'links parents' do
    expect(subject.branches['master'].children).to include 'feature'
    expect(subject.branches['feature'].children).to include 'bugfix'
    expect(subject.branches['master'].children).to include 'hotfix'
  end

  it 'converts to hash' do
    expect(subject.to_h).to eq({ version: 1,
                                 code_review_tool: nil,
                                 remote: nil,
                                 root_branch: nil,
                                 branches: branches.values.map(&:to_h) })
  end

  it 'loads from a TOML file' do
    toml = <<~TOML
      [[branches]]
      name = "master"
      sha = "123456"

      [[branches]]
      name = "feature"
      sha = "abcdef"
      parent = "master"

      [[branches]]
      name = "bugfix"
      sha = "fedcba"
      parent = "feature"

      [[branches]]
      name = "hotfix"
      sha = "654321"
      parent = "master"
    TOML

    allow(File).to receive(:read).and_return(toml)
    expect(described_class.from_toml_file('file.toml').to_h).to eq subject.to_h
  end

  context 'when deleting a branch' do
    let(:instance) { described_class.new(branches)}
    subject { instance.delete_branch('feature'); instance }
    it 'deleted the branch' do
      expect(subject.branches.keys).to_not include 'feature'
    end

    it 'relinked children' do
      expect(subject.branches['master'].children).to_not include 'feature'
    end

    it 'relinked parents' do
      expect(subject.branches['bugfix'].parent).to eq 'master'
    end
  end
end