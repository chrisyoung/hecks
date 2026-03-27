# HecksGo::PolicyGenerator
#
# Generates Go reactive policy structs. Policies subscribe to events
# and trigger commands in response.
#
module HecksGo
  class PolicyGenerator
    include GoUtils

    def initialize(policy, package:)
      @policy = policy
      @package = package
    end

    def generate
      lines = []
      lines << "package #{@package}"
      lines << ""
      lines << "// #{@policy.name} reacts to #{@policy.event_name}"
      if @policy.respond_to?(:trigger_command) && @policy.trigger_command
        lines << "// and triggers #{@policy.trigger_command}"
      end
      lines << "type #{@policy.name} struct{}"
      lines << ""
      lines << "func (p #{@policy.name}) EventName() string { return \"#{@policy.event_name}\" }"
      lines << ""
      lines << "func (p #{@policy.name}) Execute(event interface{}) {"
      lines << "\t// TODO: dispatch trigger command"
      lines << "}"

      lines.join("\n") + "\n"
    end
  end
end
