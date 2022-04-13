require_relative 'em_test_helper'

class TestTickTiming < Test::Unit::TestCase
  MICROSECONDS_PER_SECOND = 1_000_000.0

  NEXT_TICK_SLEEP = -> do
    sleep(0.100)
  end
  TIMER_SLEEP_SHORT = -> do
    EM.next_tick(&NEXT_TICK_SLEEP)
    sleep(0.200)
  end
  TIMER_SLEEP_LONG = -> do
    sleep(0.300)
  end

  def assert_time_range(start_and_end, min_seconds, range_seconds = 0.050)
    seconds = (start_and_end.last - start_and_end.first)/MICROSECONDS_PER_SECOND
    assert seconds > min_seconds, "#{seconds} > #{min_seconds}"
    assert seconds < min_seconds + range_seconds, "#{seconds} < #{min_seconds + range_seconds}"
  end

  def test_basic_tick_timing
    EM.enable_tick_timing(max_samples: 10_000, sample_probability: 1.0)

    timing_samples = now_tick_count = now = nil

    EM.run do
      EM.add_timer(0.020, &TIMER_SLEEP_SHORT)
      EM.add_timer(0.500, &TIMER_SLEEP_LONG)
      EM.add_timer(1.5) do
        timing_samples = EventMachine.get_tick_timing_samples
        now_tick_count = EventMachine.get_real_time
        now = Time.now

        EM.stop
      end
    end

    if ENV['VERBOSE']
      puts "********** #{now_tick_count}"
      timing_samples.each do |tick_type, callback_proc, start_tick_count, end_tick_count|
        latency_seconds = (end_tick_count - start_tick_count)/MICROSECONDS_PER_SECOND
        sample_seconds_ago = (now_tick_count - start_tick_count)/MICROSECONDS_PER_SECOND
        sample_time = now - sample_seconds_ago
        puts "%-20s  %0.5f  %0.5f  %s" % [EventMachine::TICK_TYPES[tick_type] || tick_type, -sample_seconds_ago, latency_seconds, callback_proc.inspect]
      end
      puts "**********"
    end

    assert_equal [:TimerFired, :TimerFired, :LoopbreakSignalled, :TimerFired],
                 timing_samples.map { |tick_type, _, _, _| EventMachine::TICK_TYPES[tick_type] || tick_type }

    assert_equal [TIMER_SLEEP_SHORT, :run_deferred_callbacks, TIMER_SLEEP_LONG],
                 timing_samples[1..-1].map { |_, callback_proc, _, _| callback_proc }

    assert_time_range timing_samples[0][2..3], 0.000
    assert_time_range timing_samples[1][2..3], 0.200  # TIMER_SLEEP_SHORT
    assert_time_range timing_samples[2][2..3], 0.100  # NEXT_TICK_SLEEP
    assert_time_range timing_samples[3][2..3], 0.300  # TIMER_SLEEP_LONG
  end

  def test_tick_timing_max_samples
    EM.enable_tick_timing(max_samples: 2, sample_probability: 1.0)

    timing_samples = now_tick_count = now = nil

    EM.run do
      EM.add_timer(0.020, &TIMER_SLEEP_SHORT)
      EM.add_timer(0.500, &TIMER_SLEEP_LONG)
      EM.add_timer(1.5) do
        timing_samples = EventMachine.get_tick_timing_samples
        now_tick_count = EventMachine.get_real_time
        now = Time.now

        EM.stop
      end
    end

    assert_equal [:TimerFired, :TimerFired],
                 timing_samples.map { |tick_type, _, _, _| EventMachine::TICK_TYPES[tick_type] || tick_type }
  end

  def test_tick_timing_probability_never
    EM.enable_tick_timing(sample_probability: 0.0)

    timing_samples = now_tick_count = now = nil

    EM.run do
      EM.add_timer(0.020, &TIMER_SLEEP_SHORT)
      EM.add_timer(0.500, &TIMER_SLEEP_LONG)
      EM.add_timer(1.5) do
        timing_samples = EventMachine.get_tick_timing_samples
        now_tick_count = EventMachine.get_real_time
        now = Time.now

        EM.stop
      end
    end

    assert_equal 0, timing_samples.size
  end

  def test_tick_timing_probability_rare
    EM.enable_tick_timing(sample_probability: 0.10)

    timing_samples = now_tick_count = now = nil

    EM.run do
      EM.add_timer(0.020, &TIMER_SLEEP_SHORT)
      EM.add_timer(0.500, &TIMER_SLEEP_LONG)
      EM.add_timer(1.5) do
        timing_samples = EventMachine.get_tick_timing_samples
        now_tick_count = EventMachine.get_real_time
        now = Time.now

        EM.stop
      end
    end

    # this is tricky to test since it's based on rand()
    # but as long as at least one sample was skipped, we'll assume it's good.
    assert timing_samples.size < 4, timing_samples.size.to_s
  end
end
