# Hecks::CLI console command
#
module Hecks
  class CLI < Thor
    desc "console [NAME]", "Start an interactive session"
    def console(name = nil)
      Session::ConsoleRunner.new(name: name).run
    end
  end
end
