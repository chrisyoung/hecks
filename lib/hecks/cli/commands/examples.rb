# Hecks::CLI Examples subcommand
#
# Regenerates the example domains. Only works inside the hecks project
# directory (checks for examples/ folder).
#
#   hecks examples generate
#
module Hecks
  class CLI < Thor
    class Examples < Thor
      desc "generate", "Regenerate all example domains"
      def generate
        examples_dir = File.join(Dir.pwd, "examples")
        unless File.directory?(examples_dir)
          say "No examples/ directory found. Run this from the hecks project root.", :red
          return
        end

        lib_dir = File.join(Dir.pwd, "lib")
        %w[pizzas/app.rb multi_domain/app.rb].each do |script|
          path = File.join(examples_dir, script)
          if File.exist?(path)
            say "Running #{script}...", :green
            system("ruby", "-I", lib_dir, path)
          else
            say "Skipping #{script} (not found)", :yellow
          end
        end

        say "Examples regenerated.", :green
      end
    end

    desc "examples SUBCOMMAND", "Example domain commands"
    subcommand "examples", Examples
  end
end
