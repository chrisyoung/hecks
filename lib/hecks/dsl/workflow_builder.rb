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
      end

      def step(command_name, **mapping)
        @steps << { command: command_name.to_s, mapping: mapping }
      end

      def branch(&block)
        branch_builder = BranchBuilder.new
        branch_builder.instance_eval(&block)
        @steps << { branch: branch_builder.build }
      end

      def build
        DomainModel::Behavior::Workflow.new(name: @name, steps: @steps)
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
