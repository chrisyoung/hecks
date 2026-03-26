# HecksWatchers::LogReader
#
# Reads and clears +tmp/watcher.log+ so Claude Code sessions see watcher
# output. Called by the PostToolUse hook.
#
#   HecksWatchers::LogReader.call("/path/to/project")
#
module HecksWatchers
  class LogReader
    # Reads the log file, prints its contents, and clears it.
    #
    # @param project_root [String] path to the project root
    # @return [String, nil] the log contents, or nil if empty/missing
    def self.call(project_root)
      log_file = File.join(project_root, "tmp", "watcher.log")
      return nil unless File.exist?(log_file)

      content = File.read(log_file).strip
      return nil if content.empty?

      File.write(log_file, "")
      puts content
      content
    end
  end
end
