# Hecks::Generators::Domain::WorkflowGenerator
#
# Generates workflow classes that orchestrate multi-step domain processes
# with conditional branching. Implements call for uniform interface.
# Part of Generators::Domain.
#
#   gen = WorkflowGenerator.new(workflow, domain_module: "ModelRegistryDomain")
#   gen.generate
#
module Hecks
  module Generators
    module Domain
    class WorkflowGenerator

      def initialize(workflow, domain_module:)
        @workflow = workflow
        @domain_module = domain_module
      end

      def generate
        lines = []
        lines << "module #{@domain_module}"
        lines << "  module Workflows"
        lines << "    class #{@workflow.name}"
        lines << "      unless defined?(STEPS)"
        lines << "        STEPS = ["
        @workflow.steps.each do |step|
          lines.concat(step_lines(step, "          "))
        end
        lines << "        ].freeze"
        lines << "      end"
        lines << ""
        lines << "      attr_reader :results"
        lines << ""
        lines << "      def call(**attrs)"
        lines << "        @results = []"
        lines << "        # Execute steps in sequence, evaluate branches"
        lines << "        self"
        lines << "      end"
        lines << "    end"
        lines << "  end"
        lines << "end"
        lines.join("\n") + "\n"
      end

      private

      def step_lines(step, indent)
        if step.respond_to?(:command) && step.command
          ["#{indent}{ command: #{step.command.inspect} },"]
        elsif step.respond_to?(:branches) && step.branches
          lines = ["#{indent}{ branch: {"]
          step.branches.each do |branch|
            if branch.respond_to?(:spec) && branch.spec
              lines << "#{indent}    spec: #{branch.spec.inspect},"
              lines << "#{indent}    when_satisfied: #{branch.steps.map { |s| { command: s.command } }.inspect},"
            else
              lines << "#{indent}    otherwise: #{branch.steps.map { |s| { command: s.command } }.inspect},"
            end
          end
          lines << "#{indent}} },"
          lines
        else
          ["#{indent}{ command: #{step.to_s.inspect} },"]
        end
      end
    end
    end
  end
end
