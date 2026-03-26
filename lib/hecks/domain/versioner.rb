# Hecks::Versioner
#
# Calendar-based versioning for domain gems. Each build stamps the current
# date with an auto-incrementing build number: 2026.03.20.1, 2026.03.20.2, etc.
#
# The version tells you when the domain was defined, not what changed.
# No manual bumping — every build gets the next number automatically.
#
#   versioner = Hecks::Versioner.new(".")
#   versioner.current   # => "2026.03.20.1"
#   versioner.next      # => "2026.03.20.2"
#   versioner.next      # => "2026.03.20.3"
#   # next day:
#   versioner.next      # => "2026.03.21.1"
#
require "date"

module Hecks
  class Versioner
    VERSION_FILE = ".hecks_version"

    def initialize(path)
      @path = path
      @version_file = File.join(path, VERSION_FILE)
    end

    def current
      if File.exist?(@version_file)
        File.read(@version_file).strip
      else
        nil
      end
    end

    def next
      today = Date.today.strftime("%Y.%m.%d")
      prev = current

      build = if prev && prev.start_with?(today)
                # Same day — increment the build number
                prev.split(".").last.to_i + 1
              else
                1
              end

      version = "#{today}.#{build}"
      File.write(@version_file, version)
      version
    end
  end
end
