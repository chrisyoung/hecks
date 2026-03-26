module HecksWatchers
  # HecksWatchers::Logger
  #
  # Shared logging for all watchers. Writes to both stdout and a log file
  # that the PostToolUse hook reads to surface warnings in Claude sessions.
  #
  #   logger = HecksWatchers::Logger.new("/path/to/project")
  #   logger.log("⚠  file too long")
  #
  class Logger
    # @param project_root [String] path to the project root
    def initialize(project_root)
      @log_file = File.join(project_root, "tmp", "watcher.log")
    end

    # Writes a message to stdout and appends it to the log file.
    #
    # @param msg [String] the message to log
    # @return [void]
    def log(msg)
      puts msg
      File.open(@log_file, "a") { |f| f.puts msg }
    end
  end
end
