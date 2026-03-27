# HecksGo::LifecycleGenerator
#
# Generates Go lifecycle support: status type, state constants,
# predicate methods, and transition validation.
#
module HecksGo
  class LifecycleGenerator
    include GoUtils

    def initialize(lifecycle, aggregate_name:, package:)
      @lc = lifecycle
      @agg = aggregate_name
      @package = package
    end

    def generate
      field = GoUtils.pascal_case(@lc.field)
      lines = []
      lines << "package #{@package}"
      lines << ""

      # State constants
      lines << "const ("
      @lc.states.each do |state|
        const_name = "#{@agg}Status#{GoUtils.pascal_case(state)}"
        lines << "\t#{const_name} = \"#{state}\""
      end
      lines << ")"
      lines << ""

      # Predicate methods
      @lc.states.each do |state|
        method = "Is#{GoUtils.pascal_case(state)}"
        const_name = "#{@agg}Status#{GoUtils.pascal_case(state)}"
        lines << "func (a *#{@agg}) #{method}() bool { return a.#{field} == #{const_name} }"
      end
      lines << ""

      # Transition validation
      lines << "func (a *#{@agg}) ValidTransition(target string) bool {"
      lines << "\tswitch {"
      @lc.transitions.each do |cmd_name, target_state|
        from = @lc.from_for(cmd_name)
        if from
          if from.is_a?(Array)
            from_check = from.map { |f| "a.#{field} == \"#{f}\"" }.join(" || ")
          else
            from_check = "a.#{field} == \"#{from}\""
          end
          lines << "\tcase target == \"#{target_state}\" && (#{from_check}): return true"
        else
          lines << "\tcase target == \"#{target_state}\": return true"
        end
      end
      lines << "\tdefault: return false"
      lines << "\t}"
      lines << "}"

      lines.join("\n") + "\n"
    end
  end
end
