# frozen_string_literal: true

class Experiment
  class << self
    def protocol(name)
      name = String(name)
      raise('Please provide an experiment name') if name.empty?
      experiment = Experiment.new(name)
      yield(experiment)
      experiment.raise_on_diff! if rails_test_mode?
      experiment.result
    end

    def rails_test_mode?
      defined?(Rails) && Rails.env.test?
    end
  end

  class Result
    attr_accessor :value, :error
    def initialize(value: nil, error: nil)
      self.value = value
      self.error = error
    end
  end

  DEFAULT_COMPARISON = ->(legacy, experiment) { legacy == experiment }
  DEFAULT_ENABLER = -> { true }

  def initialize(name)
    @name = name
    @compare_with = DEFAULT_COMPARISON
    @enable = DEFAULT_ENABLER
  end

  def legacy(&block)
    raise 'Missing block' unless block
    @legacy = block
    self
  end

  def experiment(&block)
    raise 'Missing block' unless block
    @experiment = block
    self
  end

  def compare_with(&block)
    raise 'Missing block' unless block
    @compare_with = block
    self
  end

  def enable(&block)
    raise 'Missing block' unless block
    @enable = block
    self
  end

  def on_diff(&block)
    raise 'Missing block' unless block
    @on_diff = block
    self
  end

  def result
    raise 'Please call the legacy helper in your protocol block' unless @legacy
    raise 'Please call the experiment helper in your protocol block' unless @experiment
    legacy_result = exec(@legacy)
    return forward(legacy_result) unless self.class.rails_test_mode? || @enable.call
    experiment_result = exec(@experiment)
    if @on_diff
      if legacy_result.error.class != experiment_result.error.class ||
          legacy_result.error&.message != experiment_result.error&.message ||
          !@compare_with.call(legacy_result.value, experiment_result.value)
        @on_diff.call(legacy_result, experiment_result)
      end
    end
    forward(legacy_result)
  end

  def raise_on_diff!
    on_diff do |legacy_result, experiment_result|
      raise ExperimentError,
        "Experiment: #{@name}; "\
        "Legacy result: #{legacy_result.inspect}; "\
        "Experiment result: #{experiment_result.inspect}"
    end
  end

  private

  def forward(result)
    raise result.error if result.error
    result.value
  end

  def exec(block)
    Result.new(value: block.call)
  rescue StandardError => error
    Result.new(error: error)
  end

  class ExperimentError < StandardError; end
end
