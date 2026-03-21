# Hecks::MigrationStrategy
#
# Base class for adapter-specific migration generators. Each strategy
# knows how to turn domain Change objects into migration files for its
# storage backend.
#
# Subclass and implement #generate to create a custom strategy:
#
#   class RedisMigrationStrategy < Hecks::MigrationStrategy
#     def generate(changes)
#       # return migration content or nil if nothing to do
#     end
#
#     def file_path
#       "db/redis/#{timestamp}_migration.rb"
#     end
#   end
#
# Register strategies so MigrationStrategy.run_all picks them up:
#
#   Hecks::MigrationStrategy.register(:redis, RedisMigrationStrategy)
#
module Hecks
  class MigrationStrategy
    @registry = {}

    class << self
      attr_reader :registry

      def register(name, strategy_class)
        @registry[name.to_sym] = strategy_class
      end

      def for(name)
        @registry[name.to_sym]
      end

      def all
        @registry.values
      end

      # Run all registered strategies against a set of changes
      def run_all(changes, output_dir: ".")
        return [] if changes.empty?

        files = []
        @registry.each do |name, strategy_class|
          strategy = strategy_class.new(output_dir: output_dir)
          result = strategy.generate(changes)
          if result
            path = strategy.write(result)
            files << path if path
          end
        end
        files
      end
    end

    def initialize(output_dir: ".")
      @output_dir = output_dir
    end

    # Override in subclass: return migration content string, or nil
    def generate(changes)
      raise NotImplementedError
    end

    # Override in subclass: return the file path for the migration
    def file_path
      raise NotImplementedError
    end

    # Write the migration to disk
    def write(content)
      path = File.join(@output_dir, file_path)
      FileUtils.mkdir_p(File.dirname(path))
      File.write(path, content)
      path
    end
  end
end
