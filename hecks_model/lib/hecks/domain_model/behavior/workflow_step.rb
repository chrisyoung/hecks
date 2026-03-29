# Hecks::DomainModel::Behavior::WorkflowStep
#
# Value objects for workflow steps, replacing plain hashes.
# Two concrete types: CommandStep and BranchStep.
#
#   step = CommandStep.new(command: "ScoreLoan", mapping: { score: :principal })
#   step.command   # => "ScoreLoan"
#   step[:command] # => "ScoreLoan"  (backward compat)
#
module Hecks
  module DomainModel
    module Behavior
      class CommandStep
        attr_reader :command, :mapping

        def initialize(command:, mapping: {}, **rest)
          @command = command.to_s
          @mapping = mapping
          @extra = rest
        end

        # Hash-style access for backward compatibility
        def [](key)
          case key
          when :command then @command
          when :mapping then @mapping
          else @extra[key]
          end
        end

        def key?(key)
          %i[command mapping].include?(key) || @extra.key?(key)
        end

        def to_h
          { command: @command, mapping: @mapping }.merge(@extra)
        end
      end

      class BranchStep
        attr_reader :spec, :if_steps, :else_steps

        def initialize(spec:, if_steps: [], else_steps: [])
          @spec = spec
          @if_steps = if_steps
          @else_steps = else_steps
        end

        # Hash-style access for backward compatibility
        def [](key)
          case key
          when :branch then self
          when :spec then @spec
          when :if_steps then @if_steps
          when :else_steps then @else_steps
          end
        end

        def key?(key)
          key == :branch
        end

        def to_h
          { branch: { spec: @spec, if_steps: @if_steps.map { |s| s.respond_to?(:to_h) ? s.to_h : s }, else_steps: @else_steps.map { |s| s.respond_to?(:to_h) ? s.to_h : s } } }
        end
      end

      class ScheduledStep
        attr_reader :name, :find_aggregate, :find_spec, :find_query, :trigger

        def initialize(name:, find_aggregate:, find_spec: nil, find_query: nil, trigger:)
          @name = name
          @find_aggregate = find_aggregate
          @find_spec = find_spec
          @find_query = find_query
          @trigger = trigger
        end

        def [](key)
          send(key) if respond_to?(key)
        end

        def to_h
          { name: @name, find_aggregate: @find_aggregate, find_spec: @find_spec,
            find_query: @find_query, trigger: @trigger }
        end
      end
    end
  end
end
