module HecksWatchers
  # HecksWatchers::DocReminder
  #
  # Reminds about doc updates when lib/ files are staged. Checks that
  # FEATURES.md and component CHANGELOGs are updated alongside lib changes.
  #
  #   watcher = HecksWatchers::DocReminder.new(project_root: Dir.pwd)
  #   watcher.call   # prints reminders for missing doc updates
  #
  class DocReminder
    COMPONENTS = %w[
      hecksties hecks_model hecks_domain hecks_runtime
      hecks_session hecks_cli hecks_persist hecks_on_rails
    ].freeze

    # @param project_root [String] path to the project root
    # @param logger [Logger, nil] optional logger; creates one if omitted
    def initialize(project_root:, logger: nil)
      @project_root = project_root
      @logger = logger || Logger.new(project_root)
    end

    # Checks staged files for missing doc updates.
    #
    # @return [Array<String>] list of reminder messages (empty if none)
    def call
      staged = staged_files
      lib_changes = staged.select { |f| f.match?(%r{/lib/}) }
      return [] if lib_changes.empty?

      warnings = []
      warnings.concat(check_features(staged))
      warnings.concat(check_changelogs(staged, lib_changes))

      unless warnings.empty?
        @logger.log "\n📝 Doc reminders:"
        warnings.each { |w| @logger.log w }
        @logger.log ""
      end
      warnings
    end

    private

    def staged_files
      Dir.chdir(@project_root) do
        `git diff --cached --name-only`.split("\n")
      end
    end

    def check_features(staged)
      return [] if staged.include?("FEATURES.md")

      new_files = Dir.chdir(@project_root) do
        `git diff --cached --diff-filter=A --name-only`.split("\n")
      end
      return [] unless new_files.any? { |f| f.match?(%r{/lib/}) }

      ["  FEATURES.md — new lib files added but FEATURES.md not updated"]
    end

    def check_changelogs(staged, lib_changes)
      COMPONENTS.filter_map do |c|
        next unless lib_changes.any? { |f| f.start_with?("#{c}/") }
        next if staged.include?("#{c}/CHANGELOG.md")

        "  #{c}/CHANGELOG.md — lib changes without changelog entry"
      end
    end
  end
end
