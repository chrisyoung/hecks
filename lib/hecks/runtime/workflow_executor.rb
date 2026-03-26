# Hecks::WorkflowExecutor
#
# Executes workflow steps in order against the runtime's command bus.
# At branches, evaluates the named specification against the last command
# result to choose the if_steps or else_steps path. Uses the domain module
# to resolve specification classes.
#
#   executor = WorkflowExecutor.new(workflow, command_bus, domain_mod)
#   result = executor.call(principal: 75_000)
#
module Hecks
  class WorkflowExecutor
    def initialize(workflow, command_bus, domain_mod)
      @workflow = workflow
      @command_bus = command_bus
      @domain_mod = domain_mod
    end

    def call(**initial_attrs)
      execute_steps(@workflow.steps, initial_attrs)
    end

    private

    def execute_steps(steps, attrs)
      result = nil

      steps.each do |step|
        if step[:command]
          result = dispatch_step(step, attrs, result)
        elsif step[:branch]
          result = execute_branch(step[:branch], attrs, result)
        end
      end

      result
    end

    def dispatch_step(step, attrs, last_result)
      mapped = apply_mapping(step[:mapping], attrs, last_result)
      @command_bus.dispatch(step[:command], **mapped)
    end

    def execute_branch(branch, attrs, last_result)
      spec_class = find_specification(branch[:spec])

      chosen = if spec_class && spec_class.satisfied_by?(last_result)
        branch[:if_steps]
      else
        branch[:else_steps]
      end

      execute_steps(chosen, attrs)
    end

    def find_specification(spec_name)
      @domain_mod.constants.each do |agg_const|
        agg_mod = @domain_mod.const_get(agg_const)
        next unless agg_mod.is_a?(Module)
        specs = begin; agg_mod.const_get(:Specifications); rescue NameError; next; end
        return specs.const_get(spec_name) if specs.const_defined?(spec_name)
      end
      nil
    end

    def apply_mapping(mapping, initial_attrs, last_result)
      return initial_attrs if mapping.empty? || last_result.nil?

      mapped = initial_attrs.dup
      mapping.each do |from, to|
        value = last_result.respond_to?(from) ? last_result.send(from) : initial_attrs[from]
        mapped[to.to_sym] = value if value
      end
      mapped
    end
  end
end
