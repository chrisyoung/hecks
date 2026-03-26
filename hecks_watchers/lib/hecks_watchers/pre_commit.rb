module HecksWatchers
  # HecksWatchers::PreCommit
  #
  # Runs all watchers as a pre-commit check. CrossRequire blocks the commit;
  # the rest are advisory warnings. Replaces individual bin/ script calls.
  #
  #   result = HecksWatchers::PreCommit.new(project_root: Dir.pwd).call
  #   exit 1 unless result
  #
  class PreCommit
    # @param project_root [String] path to the project root
    # @param logger [Logger, nil] optional logger; creates one if omitted
    def initialize(project_root:, logger: nil)
      @project_root = project_root
      @logger = logger || Logger.new(project_root)
    end

    # Runs all watchers. Returns false if any blocking watcher fails.
    #
    # @return [Boolean] true if commit should proceed, false to block
    def call
      blockers = run_blocking
      run_advisory
      blockers.empty?
    end

    private

    def run_blocking
      CrossRequire.new(project_root: @project_root, logger: @logger).call
    end

    def run_advisory
      FileSize.new(project_root: @project_root, logger: @logger).call
      DocReminder.new(project_root: @project_root, logger: @logger).call
      SpecCoverage.new(project_root: @project_root, logger: @logger).call
      Autoloads.new(project_root: @project_root, logger: @logger).call
    end
  end
end
