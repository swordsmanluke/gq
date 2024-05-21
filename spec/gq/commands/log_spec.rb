# frozen_string_literal: true

require_relative '../../spec_helper'

RSpec.describe Log do

  let(:stack) { double(Stack) }
  let(:git) { double(Git) }
  let(:instance) { described_class.new(stack, git) }

  context 'when logging branches' do
    subject(:branches) { instance.sorted_branches }

    it 'returns the sorted branches' do
      allow(stack).to receive(:stacks).and_return([['branch1', 'branch2'], ['branch1', 'branch3', 'branch4']])

      expect(branches).to eq([
                               # Stack 1: b1 -> b2
                               # Stack 2: b1 -> b3 -> b4
                               { depth: 0, name: 'branch1', stacks: [0,1] },
                               { depth: 1, name: 'branch2', stacks: [0] },
                               { depth: 1, name: 'branch3', stacks: [1] },
                               { depth: 2, name: 'branch4', stacks: [1] },
                             ])
    end
  end
  context 'when displaying branches' do
    subject(:display) { instance.as_string }

    it 'displays split branches' do
      allow(stack).to receive(:stacks).and_return([['branch1', 'branch2'], ['branch1', 'branch3', 'branch4']])

      expect(display).to eq([
        "o branch1",
        " | o branch2",
        "o branch3",
        "   o branch4"
      ])
    end
  end

end
