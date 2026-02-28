# frozen_string_literal: true

describe Grape::Validations::ParamScopeTracker do
  describe '.current' do
    it 'returns nil when no tracker is active' do
      expect(described_class.current).to be_nil
    end
  end

  describe '.track' do
    it 'sets .current inside the block' do
      described_class.track do
        expect(described_class.current).to be_a(described_class)
      end
    end

    it 'restores nil after the block' do
      described_class.track { nil }
      expect(described_class.current).to be_nil
    end

    it 'restores nil after an exception' do
      expect { described_class.track { raise 'boom' } }.to raise_error('boom')
      expect(described_class.current).to be_nil
    end

    it 'creates a fresh tracker for each invocation' do
      first = nil
      second = nil
      described_class.track { first = described_class.current }
      described_class.track { second = described_class.current }
      expect(first).not_to equal(second)
    end

    context 'when nested (reentrant)' do
      it 'restores the outer tracker, not nil' do
        outer = nil
        inner = nil

        described_class.track do
          outer = described_class.current
          described_class.track { inner = described_class.current }
          expect(described_class.current).to equal(outer)
        end

        expect(inner).not_to equal(outer)
        expect(described_class.current).to be_nil
      end

      it 'restores outer tracker after inner raises' do
        described_class.track do
          outer = described_class.current
          expect { described_class.track { raise 'inner' } }.to raise_error('inner')
          expect(described_class.current).to equal(outer)
        end
      end
    end
  end

  describe '#store_index / #index_for' do
    subject(:tracker) { described_class.new }

    let(:scope_a) { instance_double(Grape::Validations::ParamsScope) }
    let(:scope_b) { instance_double(Grape::Validations::ParamsScope) }

    it 'returns nil for an unknown scope' do
      expect(tracker.index_for(scope_a)).to be_nil
    end

    it 'returns the stored index for the given scope' do
      tracker.store_index(scope_a, 3)
      expect(tracker.index_for(scope_a)).to eq(3)
    end

    it 'stores indices independently per scope' do
      tracker.store_index(scope_a, 0)
      tracker.store_index(scope_b, 7)
      expect(tracker.index_for(scope_a)).to eq(0)
      expect(tracker.index_for(scope_b)).to eq(7)
    end

    it 'uses object identity, not value equality, as the key' do
      equal_double = instance_double(Grape::Validations::ParamsScope)
      tracker.store_index(scope_a, 1)
      expect(tracker.index_for(equal_double)).to be_nil
    end

    it 'overwrites a previously stored index' do
      tracker.store_index(scope_a, 1)
      tracker.store_index(scope_a, 5)
      expect(tracker.index_for(scope_a)).to eq(5)
    end
  end

  describe '#store_qualifying_params / #qualifying_params' do
    subject(:tracker) { described_class.new }

    let(:scope) { instance_double(Grape::Validations::ParamsScope) }

    it 'returns EMPTY_PARAMS for an unknown scope' do
      expect(tracker.qualifying_params(scope)).to equal(described_class::EMPTY_PARAMS)
    end

    it 'returns the stored params for the given scope' do
      params = [{ id: 1 }, { id: 2 }]
      tracker.store_qualifying_params(scope, params)
      expect(tracker.qualifying_params(scope)).to eq(params)
    end

    it 'treats an explicitly stored empty array the same as never stored (blank)' do
      tracker.store_qualifying_params(scope, [])
      expect(tracker.qualifying_params(scope).presence).to be_nil
    end

    it 'uses object identity as the key' do
      other_scope = instance_double(Grape::Validations::ParamsScope)
      tracker.store_qualifying_params(scope, [{ id: 1 }])
      expect(tracker.qualifying_params(other_scope)).to equal(described_class::EMPTY_PARAMS)
    end
  end
end
