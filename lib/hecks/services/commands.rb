# Hecks::Commands
#
# Groups command dispatch infrastructure: the CommandBus, CommandRunner,
# and CommandMethods mixin that wires command class methods onto aggregates.
#
#   Commands.bind(agg_class, aggregate, bus, repo, defaults)
#
module Hecks
  module Commands
      autoload :CommandBus,     "hecks/services/commands/command_bus"
      autoload :CommandRunner,  "hecks/services/commands/command_runner"
      autoload :CommandMethods, "hecks/services/commands/command_methods"

      def self.bind(klass, aggregate, bus, repo, defaults)
        CommandMethods.bind(klass, aggregate, bus, repo, defaults)
      end

      def self.bind_shortcuts(klass, aggregate, &block)
        CommandMethods.bind_shortcuts(klass, aggregate, &block)
      end
  end
end
