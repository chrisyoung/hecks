# Hecks::Session::Playground::GemBootstrap
#
# Compiles a domain model into a temporary gem and loads it into the runtime.
# Handles temp directory creation, gem generation via DomainGemGenerator,
# and loading all generated Ruby files into the current process.
#
# Mixed into Playground to separate gem compilation from command execution.
#
#   class Playground
#     include GemBootstrap
#     # provides: compile!
#   end
#
require "tmpdir"

module Hecks
  class Session
    class Playground
      module GemBootstrap
        private

        def compile!
          @tmpdir = Dir.mktmpdir("hecks_playground")
          generator = Generators::Infrastructure::DomainGemGenerator.new(@domain, version: "0.0.0", output_dir: @tmpdir)
          gem_path = generator.generate

          lib_path = File.join(gem_path, "lib")
          $LOAD_PATH.unshift(lib_path) unless $LOAD_PATH.include?(lib_path)

          entry = File.join(lib_path, "#{@domain.gem_name}.rb")
          load entry

          Dir[File.join(lib_path, "**/*.rb")].sort.each { |f| load f }
        end
      end
    end
  end
end
