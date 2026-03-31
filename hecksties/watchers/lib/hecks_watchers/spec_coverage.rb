module HecksWatchers
  # HecksWatchers::SpecCoverage
  #
  # Warns when a new .rb file is added to a component's +lib/+ without a
  # corresponding +_spec.rb+ in that component's +spec/+.
  #
  #   watcher = HecksWatchers::SpecCoverage.new(project_root: Dir.pwd)
  #   watcher.call   # prints warnings for uncovered files
  #
  class SpecCoverage
    # @param project_root [String] path to the project root
    # @param logger [Logger, nil] optional logger; creates one if omitted
    def initialize(project_root:, logger: nil)
      @project_root = project_root
      @logger = logger || Logger.new(project_root)
    end

    # Checks newly added lib files for missing spec files.
    #
    # @return [Array<String>] list of missing spec messages (empty if none)
    def call
      staged = staged_new_lib_files
      return [] if staged.empty?

      missing = []
      staged.each do |path|
        parts = path.split("/")
        component = parts[0]
        relative = parts[2..].join("/")
        relative = relative.sub(%r{^hecks(_\w+)?/}, "")
        spec_path = "#{component}/spec/#{relative.sub(/\.rb$/, "_spec.rb")}"
        base_spec = "#{component}/spec/#{File.basename(path, ".rb")}_spec.rb"

        full_spec = File.join(@project_root, spec_path)
        full_base = File.join(@project_root, base_spec)

        unless File.exist?(full_spec) || File.exist?(full_base)
          missing << "  #{path} → expected #{spec_path}"
        end
      end

      unless missing.empty?
        @logger.log "\n📋 New lib files without specs:"
        missing.each { |m| @logger.log m }
        @logger.log ""
      end
      missing
    end

    private

    def staged_new_lib_files
      Dir.chdir(@project_root) do
        `git diff --cached --diff-filter=A --name-only`.split("\n")
          .select { |f| f.match?(%r{^[^/]+/lib/.*\.rb$}) }
      end
    end
  end

  register_watcher(:advisory, SpecCoverage)
end
