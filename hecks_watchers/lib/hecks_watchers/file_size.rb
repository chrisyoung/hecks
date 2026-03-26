module HecksWatchers
  # HecksWatchers::FileSize
  #
  # Warns when any staged .rb file exceeds the warning threshold (180 lines
  # of code, excluding doc headers). The hard limit is 200.
  #
  #   watcher = HecksWatchers::FileSize.new(project_root: Dir.pwd)
  #   watcher.call   # prints warnings for oversized files
  #
  class FileSize
    LIMIT = 180

    # @param project_root [String] path to the project root
    # @param logger [Logger, nil] optional logger; creates one if omitted
    def initialize(project_root:, logger: nil)
      @project_root = project_root
      @logger = logger || Logger.new(project_root)
    end

    # Checks staged .rb files for size violations.
    #
    # @return [Array<String>] list of violation messages (empty if none)
    def call
      staged = staged_rb_files
      return [] if staged.empty?

      violations = []
      staged.each do |path|
        full = File.join(@project_root, path)
        next unless File.exist?(full)

        count = code_line_count(full)
        violations << "  #{path}: #{count} lines (limit: 200)" if count > LIMIT
      end

      unless violations.empty?
        @logger.log "\n⚠  Files approaching 200-line code limit:"
        violations.each { |v| @logger.log v }
        @logger.log ""
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

    # Counts code lines, skipping the leading doc header and blank/comment lines.
    #
    # @param path [String] absolute file path
    # @return [Integer] number of code lines
    def code_line_count(path)
      lines = File.readlines(path)
      in_header = true
      lines.reject do |line|
        stripped = line.strip
        if in_header && (stripped.start_with?("#") || stripped.empty?)
          true
        else
          in_header = false
          stripped.empty? || stripped.start_with?("#")
        end
      end.size
    end
  end
end
