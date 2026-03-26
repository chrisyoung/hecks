# Hecks::Generators::Domain::CommandGenerator::InjectionHelpers
#
# Extracted helpers for injecting sets, lifecycle status, and lifecycle
# guard lines into generated command constructor args. Mixed into
# CommandGenerator to keep the main file under 200 lines.
#
module Hecks
  module Generators
    module Domain
      class CommandGenerator
        module InjectionHelpers
          private

          def inject_sets(args)
            return unless @command.sets && !@command.sets.empty?
            @command.sets.each do |field, value|
              args.reject! { |argument| argument.start_with?("#{field}:") }
              if value == :now
                args << "#{field}: Time.now.to_s"
              elsif value.is_a?(Symbol)
                args << "#{field}: #{value}"
              else
                args << "#{field}: #{value.inspect}"
              end
            end
          end

          def lifecycle_guard_lines(indent)
            return [] unless @aggregate&.lifecycle
            from_state = @aggregate.lifecycle.from_for(@command.name)
            return [] unless from_state
            field = @aggregate.lifecycle.field
            if from_state.is_a?(Array)
              allowed = from_state.map(&:inspect).join(", ")
              [
                "#{indent}unless [#{allowed}].include?(existing.#{field})",
                "#{indent}  raise Hecks::Error, \"Cannot #{@command.name}: #{field} must be one of #{from_state.join(', ')}, got '\#{existing.#{field}}'\"",
                "#{indent}end",
              ]
            else
              [
                "#{indent}unless existing.#{field} == \"#{from_state}\"",
                "#{indent}  raise Hecks::Error, \"Cannot #{@command.name}: #{field} must be '#{from_state}', got '\#{existing.#{field}}'\"",
                "#{indent}end",
              ]
            end
          end

          # Detect when a command has a singular attr (e.g. "topping") that
          # maps to a list_of aggregate attr (e.g. "toppings").
          def find_list_append(agg_attr)
            return nil unless agg_attr.list?
            singular = agg_attr.name.to_s.chomp("s")
            @command.attributes.find { |c| c.name.to_s == singular }
          end

          def inject_lifecycle_status(args)
            return unless @aggregate&.lifecycle
            target = @aggregate.lifecycle.target_for(@command.name)
            return unless target
            field = @aggregate.lifecycle.field
            args.reject! { |argument| argument.start_with?("#{field}:") }
            args << "#{field}: \"#{target}\""
          end
        end
      end
    end
  end
end
