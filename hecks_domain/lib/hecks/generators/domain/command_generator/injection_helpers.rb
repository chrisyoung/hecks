# Hecks::Generators::Domain::CommandGenerator::InjectionHelpers
#
# Extracted helpers for injecting sets, lifecycle status, and lifecycle
# guard lines into generated command constructor args. Mixed into
# CommandGenerator to keep the main file under 200 lines.
#
# These helpers modify the argument arrays that are passed to +Aggregate.new+
# in the generated +call+ method, handling:
# - Explicit field overrides from the DSL's +sets+ declarations
# - Lifecycle state transitions (setting the status field to the target state)
# - Lifecycle guard checks (ensuring the aggregate is in the correct state
#   before allowing a transition)
# - List append detection (mapping singular command attrs to plural aggregate attrs)
#
module Hecks
  module Generators
    module Domain
      class CommandGenerator
        module InjectionHelpers
          private

          # Injects explicit field overrides from the command's +sets+ declarations
          # into the constructor argument list.
          #
          # Each +sets+ entry replaces any existing argument for that field.
          # Special values:
          # - +:now+ becomes +Time.now.to_s+
          # - Other symbols are emitted as bare references
          # - All other values are +inspect+ed as literals
          #
          # @param args [Array<String>] the mutable argument list to modify in-place
          # @return [void]
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

          # Generates lifecycle guard lines that check the aggregate's current state
          # before allowing a command to proceed.
          #
          # If the aggregate has a lifecycle and the command has a +from+ guard defined,
          # generates an +unless+ check that raises +Hecks::Error+ if the current state
          # does not match the required state(s).
          #
          # @param indent [String] the whitespace prefix for each generated line
          # @return [Array<String>] guard lines, or an empty array if no guard applies
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
          #
          # This enables append semantics where a singular command attribute
          # gets appended to the aggregate's list attribute rather than replacing it.
          #
          # @param agg_attr [Hecks::DomainModel::Structure::Attribute] an aggregate attribute to check
          # @return [Hecks::DomainModel::Structure::Attribute, nil] the matching singular command
          #   attribute, or nil if no match
          def find_list_append(agg_attr)
            return nil unless agg_attr.list?
            singular = agg_attr.name.to_s.chomp("s")
            @command.attributes.find { |c| c.name.to_s == singular }
          end

          # Injects the lifecycle target state into the constructor argument list.
          #
          # If the aggregate has a lifecycle and the command triggers a state transition,
          # replaces any existing argument for the lifecycle field with the target state.
          #
          # @param args [Array<String>] the mutable argument list to modify in-place
          # @return [void]
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
