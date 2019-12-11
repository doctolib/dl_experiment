require 'experiment'

RSpec.describe Experiment do
  let (:failing_experiment) do
    Experiment.protocol('failing') do |e|
      e.legacy { :legacy }
      e.experiment { :experiment }
    end
  end

  let (:successful_experiment) do
    Experiment.protocol('successful') do |e|
      e.legacy { :same_result }
      e.experiment { :same_result }
    end
  end

  context 'when in Rails test mode' do
    before { stub_const('Rails', double(env: double(test?: true))) }

    it { expect{failing_experiment}.to raise_error(Experiment::ExperimentError) }
  end

  context 'when not in test mode' do
    it { expect { Experiment.protocol(nil) }.to raise_error(/Please provide an experiment name/) }

    it { expect(failing_experiment).to eq(:legacy) }

    it { expect(successful_experiment).to eq(:same_result) }

    it 'raise when #raise_on_diff! is called and legacy != experiment' do
      expect do
        Experiment.protocol('fake experiment') do |exp|
          exp.legacy { :legacy }
          exp.experiment { :experiment }
          exp.raise_on_diff!
        end
      end.to raise_error(Experiment::ExperimentError)
    end

    it 'raise the legacy exception' do
      expect do
        Experiment.protocol('fake experiment') do |exp|
          exp.legacy { raise 'legacy' }
          exp.experiment { raise 'experiment' }
        end
      end.to raise_error(/legacy/)
    end

    it 'detect when exception messages are different' do
      on_diff_called = false
      expect do
        Experiment.protocol('fake experiment') do |exp|
          exp.legacy { raise 'legacy' }
          exp.experiment { raise 'experiment' }
          exp.on_diff { on_diff_called = true }
        end
      end.to raise_error(/legacy/)
      expect(on_diff_called).to be(true)
    end



    it 'call on_diff block when values are not equal' do
      legacy = double
      experiment = double
      on_diff_called = false
      Experiment.protocol('fake experiment') do |exp|
        exp.legacy { legacy }
        exp.experiment { experiment }
        exp.on_diff do |legacy_result, experiment_result|
          expect(legacy).to eq(legacy_result.value)
          expect(experiment).to eq(experiment_result.value)
          on_diff_called = true
        end
      end
      expect(on_diff_called).to be(true)
    end

    it 'call on_diff block when an exception is raised' do
      on_diff_called = false
      Experiment.protocol('fake experiment') do |exp|
        exp.legacy { :legacy }
        exp.experiment { raise 'experiment' }
        exp.on_diff do |legacy_result, experiment_result|
          expect(:legacy).to eq(legacy_result.value)
          expect(legacy_result.error).to be_nil
          expect(experiment_result.value).to be_nil
          expect('experiment').to eq(experiment_result.error.message)
          expect(RuntimeError).to eq(experiment_result.error.class)
          on_diff_called = true
        end
      end
      expect(on_diff_called).to be(true)
    end

    it 'use compare_with block when provided' do
      compare_with_block_called = false
      on_diff_called = false
      Experiment.protocol('fake experiment') do |exp|
        exp.legacy { :legacy }
        exp.experiment { :experiment }
        exp.compare_with do |legacy, experiment|
          compare_with_block_called = true
          expect(:legacy).to eq(legacy)
          expect(:experiment).to eq(experiment)
          true
        end
        exp.on_diff { on_diff_called = true }
      end
      expect(compare_with_block_called).to be_truthy
      expect(on_diff_called).to be_falsey
      compare_with_block_called = false
      on_diff_called = false
      Experiment.protocol('fake experiment') do |exp|
        exp.legacy { :legacy }
        exp.experiment { :experiment }
        exp.compare_with do |_legacy, _experiment|
          compare_with_block_called = true
          false
        end
        exp.on_diff { on_diff_called = true }
      end
      expect(compare_with_block_called).to be_truthy
      expect(on_diff_called).to be_truthy
    end



  end
end
