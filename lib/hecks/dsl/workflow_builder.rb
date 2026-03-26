# Hecks::DSL::WorkflowBuilder
#
# DSL builder for workflow definitions. Collects sequential steps and
# conditional branches, then builds a DomainModel::Behavior::Workflow.
#
#   builder = WorkflowBuilder.new("LoanApproval")
#   builder.step "ScoreLoan", score: :principal
#   builder.branch do
#     when_spec("HighRisk") { step "ReviewLoan" }
#     otherwise { step "ApproveLoan" }
#   end
#   workflow = builder.build
#
module Hecks
  module DSL
    class WorkflowBuilder
      def initialize(name)
        @name = name
        @steps = []
        @schedule = nil
      end

      def schedule(interval)
        @schedule = interval
      end

      def step(command_name = nil, **mapping, &block)
        if block
          step_builder = ScheduledStepBuilder.new(command_name)
          step_builder.instance_eval(&block)
          @steps << step_builder.build
        else
          @steps << { command: command_name.to_s, mapping: mapping }
        end
      end

      def branch(&block)
        branch_builder = BranchBuilder.new
        branch_builder.instance_eval(&block)
        @steps << { branch: branch_builder.build }
      end

      def build
        DomainModel::Behavior::Workflow.new(name: @name, steps: @steps, schedule: @schedule)
      end
    end

    class ScheduledStepBuilder
      def initialize(name)
        @name = name
        @find_aggregate = nil
        @find_spec = nil
        @find_query = nil
        @trigger_command = nil
      end

      def find(aggregate_name, spec: nil, query: nil)
        @find_aggregate = aggregate_name
        @find_spec = spec
        @find_query = query
      end

      def trigger(command_name)
        @trigger_command = command_name
      end

      def build
        { name: @name, find_aggregate: @find_aggregate, find_spec: @find_spec,
          find_query: @find_query, trigger: @trigger_command }
      end
    end

    class BranchBuilder
      def initialize
        @spec = nil
        @if_steps = []
        @else_steps = []
      end

      def when_spec(spec_name, &block)
        @spec = spec_name
        collector = StepCollector.new
        collector.instance_eval(&block)
        @if_steps = collector.steps
      end

      def otherwise(&block)
        collector = StepCollector.new
        collector.instance_eval(&block)
        @else_steps = collector.steps
      end

      def build
        { spec: @spec, if_steps: @if_steps, else_steps: @else_steps }
      end
    end

    class StepCollector
      attr_reader :steps

      def initialize
        @steps = []
      end

      def step(command_name, **mapping)
        @steps << { command: command_name.to_s, mapping: mapping }
      end
    end
  end
end
