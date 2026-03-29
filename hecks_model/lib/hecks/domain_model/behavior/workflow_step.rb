# Hecks::DomainModel::Behavior::WorkflowStep
#
# Base class and value objects for workflow steps. Subclasses represent
# commands, branches, and scheduled tasks within a workflow definition.
#
#   step = CommandStep.new(command: "ScoreLoan", mapping: { score: :principal })
#   step.command      # => "ScoreLoan"
#   step.is_a?(WorkflowStep)  # => true
#
module Hecks
  module DomainModel
    module Behavior
      class WorkflowStep
      end

      class CommandStep < WorkflowStep
        attr_reader :command, :mapping

        def initialize(command:, mapping: {})
          @command = command.to_s
          @mapping = mapping
        end
      end

      class BranchStep < WorkflowStep
        attr_reader :spec, :if_steps, :else_steps

        def initialize(spec:, if_steps: [], else_steps: [])
          @spec = spec
          @if_steps = if_steps
          @else_steps = else_steps
        end
      end

      class ScheduledStep < WorkflowStep
        attr_reader :name, :find_aggregate, :find_spec, :find_query, :trigger

        def initialize(name:, find_aggregate:, find_spec: nil, find_query: nil, trigger:)
          @name = name
          @find_aggregate = find_aggregate
          @find_spec = find_spec
          @find_query = find_query
          @trigger = trigger
        end
      end
    end
  end
end
