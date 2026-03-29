module HecksWatchers
  # HecksWatchers::CrossRequire
  #
  # Fails if any staged file has a +require_relative+ that escapes its
  # component boundary. Cross-component loading must use bare +require+.
  #
  #   watcher = HecksWatchers::CrossRequire.new(project_root: Dir.pwd)
  #   watcher.call   # exits 1 if violations found
  #
  class CrossRequire
    COMPONENTS = %w[
      hecksties hecks_model hecks_domain hecks_runtime
      hecks_workshop hecks_cli hecks_persist hecks_on_rails
      hecks_watchers
    ].freeze

    # @param project_root [String] path to the project root
    # @param logger [Logger, nil] optional logger; creates one if omitted
    def initialize(project_root:, logger: nil)
      @project_root = project_root
      @logger = logger || Logger.new(project_root)
    end

    # Checks staged .rb files for cross-component require_relative calls.
    #
    # @return [Array<String>] list of violation messages (empty if none)
    def call
      staged = staged_rb_files
      return [] if staged.empty?

      violations = []
      staged.each do |path|
        component = COMPONENTS.find { |c| path.start_with?("#{c}/") }
        next unless component

        full = File.join(@project_root, path)
        next unless File.exist?(full)

        File.readlines(full).each_with_index do |line, i|
          next unless line =~ /require_relative\s+["']([^"']+)/
          target = $1
          dir = File.dirname(full)
          resolved = File.expand_path(target, dir)
          unless resolved.include?("/#{component}/")
            violations << "  #{path}:#{i + 1}: require_relative \"#{target}\" escapes #{component}/"
          end
        end
      end

      unless violations.empty?
        @logger.log "\nBLOCKED: Cross-component require_relative detected:"
        violations.each { |v| @logger.log v }
        @logger.log "  Use bare `require` for cross-component loading.\n\n"
      end
      violations
    end

    private

    def staged_rb_files
      Dir.chdir(@project_root) do
        `git diff --cached --name-only`.split("\n")
          .select { |f| f.end_with?(".rb") }
      end
    end
  end

  register_watcher(:blocking, CrossRequire)
end
