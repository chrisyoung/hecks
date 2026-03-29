require "tmpdir"

module Hecks
  class Workbench
    class Playground
      # Hecks::Workbench::Playground::GemBootstrap
      #
      # Compiles a domain model into a temporary gem and loads it into the runtime.
      # Handles temp directory creation, gem generation via DomainGemGenerator,
      # and loading all generated Ruby files into the current process.
      #
      # Mixed into Playground to separate gem compilation from command execution.
      # The compile! method is called during Playground initialization.
      #
      # Generated files in commands/ and queries/ directories are skipped during
      # eager loading because they rely on const_missing to auto-include their
      # respective mixins when first accessed.
      #
      #   class Playground
      #     include GemBootstrap
      #     # provides: compile!
      #   end
      #
      module GemBootstrap
        private

        # Compile the domain into a temporary gem and load it into the process.
        #
        # Creates a temp directory, generates a full gem using DomainGemGenerator,
        # adds the gem's lib/ to $LOAD_PATH, loads the entry point, then eagerly
        # loads all non-command/query files. Commands and queries are left for
        # lazy loading via const_missing.
        #
        # @return [void]
        def compile!
          @tmpdir = Dir.mktmpdir("hecks_playground")
          generator = Generators::Infrastructure::DomainGemGenerator.new(@domain, version: "0.0.0", output_dir: @tmpdir)
          gem_path = generator.generate

          lib_path = File.join(gem_path, "lib")
          $LOAD_PATH.unshift(lib_path) unless $LOAD_PATH.include?(lib_path)

          entry = File.join(lib_path, "#{@domain.gem_name}.rb")
          load entry

          # Load non-command/query files eagerly. Commands and queries are
          # loaded lazily via const_missing which auto-includes their mixins.
          Dir[File.join(lib_path, "**/*.rb")].sort.each do |f|
            next if f.include?("/commands/") || f.include?("/queries/")
            load f
          end
        end
      end
    end
  end
end
