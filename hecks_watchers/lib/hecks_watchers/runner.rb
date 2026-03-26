# HecksWatchers::Runner
#
# Polls the project for .rb file changes every second and runs all
# watchers when changes are detected. This replaces +bin/watch-all+.
#
#   runner = HecksWatchers::Runner.new(project_root: Dir.pwd)
#   runner.start   # blocks, polling forever
#
module HecksWatchers
  class Runner
    # @param project_root [String] path to the project root
    # @param interval [Numeric] seconds between polls (default: 1)
    # @param logger [Logger, nil] optional logger; creates one if omitted
    def initialize(project_root:, interval: 1, logger: nil)
      @project_root = project_root
      @interval = interval
      @logger = logger || Logger.new(project_root)
      @snapshot = {}
    end

    # Starts the polling loop. Blocks indefinitely.
    #
    # @return [void]
    def start
      @snapshot = snapshot_files
      loop do
        sleep @interval
        check_once
      end
    end

    # Runs a single poll cycle. Useful for testing.
    #
    # @return [Array<String>] list of changed file paths (empty if none)
    def check_once
      current = snapshot_files
      changed = current.keys.select { |f| current[f] != @snapshot[f] }
      added = current.keys - @snapshot.keys
      removed = @snapshot.keys - current.keys

      unless changed.empty? && added.empty? && removed.empty?
        all = (changed + added).uniq
        @logger.log "\n──── #{all.size} file(s) changed ────"
        all.each { |f| @logger.log "  #{f}" }
        run_watchers
        @logger.log "────────────────────────────────"
        @snapshot = current
        return all
      end
      []
    end

    private

    def snapshot_files
      Dir.chdir(@project_root) do
        Dir.glob("*/lib/**/*.rb").each_with_object({}) do |f, h|
          h[f] = File.mtime(f) rescue nil
        end
      end
    end

    def run_watchers
      FileSize.new(project_root: @project_root, logger: @logger).call
      CrossRequire.new(project_root: @project_root, logger: @logger).call
      Autoloads.new(project_root: @project_root, logger: @logger).call
    end
  end
end
