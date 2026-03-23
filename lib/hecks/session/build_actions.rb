# Hecks::Session::BuildActions
#
# Session methods for validating, previewing, building, and saving
# the domain being constructed. Part of the Session layer -- mixed
# into Session to keep build-phase logic separate from play-mode.
#
#   session.validate
#   session.preview("Pizza")
#   session.build(version: "1.0.0")
#   session.save("hecks_domain.rb")
#
module Hecks
  class Session
    module BuildActions
      def validate
        domain = to_domain
        valid, errors = Hecks.validate(domain)

        if valid
          puts "Valid (#{domain.aggregates.size} aggregates, #{total_commands(domain)} commands, #{total_events(domain)} events)"
        else
          puts "Invalid:"
          errors.each { |e| puts "  - #{e}" }
        end

        valid
      end

      def preview(aggregate_name = nil)
        domain = to_domain

        if aggregate_name
          puts Hecks.preview(domain, aggregate_name)
        else
          domain.aggregates.each do |agg|
            puts "# === #{agg.name} ==="
            puts Hecks.preview(domain, agg.name)
            puts
          end
        end
        nil
      end

      def build(version: nil, output_dir: ".")
        domain = to_domain
        version ||= next_version
        path = Hecks.build(domain, version: version, output_dir: output_dir)
        puts "Built #{domain.gem_name} v#{version} -> #{path}/"
        path
      end

      def save(path = "hecks_domain.rb")
        File.write(path, to_dsl)
        puts "Saved to #{path}"
        path
      end

      def to_dsl
        DslSerializer.new(to_domain).serialize
      end

      private

      def total_commands(domain)
        domain.aggregates.sum { |a| a.commands.size }
      end

      def total_events(domain)
        domain.aggregates.sum { |a| a.events.size }
      end

      def next_version
        Versioner.new(".").next
      end
    end
  end
end
