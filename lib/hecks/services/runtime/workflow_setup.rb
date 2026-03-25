# Hecks::Runtime::WorkflowSetup
#
# Mixin that binds workflow executors as callable methods on the domain
# module at boot time. Each workflow becomes a method that accepts keyword
# arguments and executes the workflow steps through the command bus.
#
#   class Runtime
#     include WorkflowSetup
#   end
#
module Hecks
  class Runtime
    module WorkflowSetup
      private

      def setup_workflows
        return unless @domain.respond_to?(:workflows)

        @domain.workflows.each do |workflow|
          executor = WorkflowExecutor.new(workflow, @command_bus, @mod)
          method_name = Hecks::Utils.underscore(workflow.name).to_sym

          @mod.define_singleton_method(method_name) do |**attrs|
            executor.call(**attrs)
          end
        end
      end
    end
  end
end
