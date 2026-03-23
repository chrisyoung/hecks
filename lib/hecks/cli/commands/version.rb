# Hecks::CLI version command
#
module Hecks
  class CLI < Thor
    desc "version", "Show current domain version"
    def version
      versioner = Versioner.new(".")
      say versioner.current
    end
  end
end
