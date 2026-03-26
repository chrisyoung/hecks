# HecksWatchers::Autoloads
#
# Warns when a new class/module file is added but not registered in
# +hecksties/lib/hecks/autoloads.rb+.
#
#   watcher = HecksWatchers::Autoloads.new(project_root: Dir.pwd)
#   watcher.call   # prints warnings for unregistered files
#
module HecksWatchers
  class Autoloads
    AUTOLOADS_REL = "hecksties/lib/hecks/autoloads.rb"

    # @param project_root [String] path to the project root
    # @param logger [Logger, nil] optional logger; creates one if omitted
    def initialize(project_root:, logger: nil)
      @project_root = project_root
      @logger = logger || Logger.new(project_root)
    end

    # Checks newly added staged files for missing autoload registration.
    #
    # @return [Array<String>] list of missing class names (empty if none)
    def call
      staged = staged_new_lib_files
      return [] if staged.empty?

      autoloads_path = File.join(@project_root, AUTOLOADS_REL)
      autoloads = File.exist?(autoloads_path) ? File.read(autoloads_path) : ""

      missing = []
      staged.each do |path|
        basename = File.basename(path, ".rb")
        class_name = basename.split("_").map(&:capitalize).join
        unless autoloads.include?(":#{class_name},") || autoloads.include?(":#{class_name} ")
          missing << "  #{class_name} (#{path})"
        end
      end

      unless missing.empty?
        @logger.log "\n📦 New files possibly missing from autoloads.rb:"
        missing.each { |m| @logger.log m }
        @logger.log "  Check #{AUTOLOADS_REL}\n\n"
      end
      missing
    end

    private

    def staged_new_lib_files
      Dir.chdir(@project_root) do
        `git diff --cached --diff-filter=A --name-only`.split("\n")
          .select { |f| f.match?(%r{^[^/]+/lib/hecks/.*\.rb$}) }
      end
    end
  end
end
