# HecksFailover::RecoveryMonitor
#
# Coordinates recovery across all FailoverProxy instances. Provides a
# synchronous recover! method that attempts recovery on every proxy that
# is currently in failover mode. Designed to be called periodically by
# a background thread or on-demand via Hecks.failover_recover!.
#
# Usage:
#   monitor = HecksFailover::RecoveryMonitor.new(proxies)
#   monitor.recover!                    # try all proxies now
#   monitor.start(interval: 30)         # background thread every 30s
#   monitor.stop                        # stop background thread
#
module HecksFailover
  class RecoveryMonitor
    # Create a monitor for the given proxies.
    #
    # @param proxies [Array<FailoverProxy>] the proxies to monitor
    # @return [RecoveryMonitor]
    def initialize(proxies)
      @proxies = proxies
      @thread = nil
    end

    # Attempt recovery on all failed-over proxies.
    #
    # Iterates through proxies, calling recover! on each that is in
    # failover mode. Returns a hash with counts of recovered and
    # still-failed proxies.
    #
    # @return [Hash] { recovered: Integer, still_failed: Integer }
    def recover!
      recovered = 0
      still_failed = 0

      @proxies.each do |proxy|
        next unless proxy.failed_over?
        if proxy.recover!
          recovered += 1
        else
          still_failed += 1
        end
      end

      { recovered: recovered, still_failed: still_failed }
    end

    # Start a background recovery thread.
    #
    # Spawns a daemon thread that calls recover! at the given interval.
    # Only one background thread runs at a time; calling start again
    # is a no-op if already running.
    #
    # @param interval [Numeric] seconds between recovery attempts (default: 30)
    # @return [void]
    def start(interval: 30)
      return if @thread&.alive?

      @thread = Thread.new do
        loop do
          sleep(interval)
          recover!
        end
      end
      @thread.abort_on_exception = false
      nil
    end

    # Stop the background recovery thread.
    #
    # @return [void]
    def stop
      @thread&.kill
      @thread = nil
    end
  end
end
