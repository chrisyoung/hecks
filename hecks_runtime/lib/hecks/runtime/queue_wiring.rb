DomainNaming = Hecks::Templating::Names

module Hecks
  module Boot
    # Hecks::Boot::QueueWiring
    #
    # Wires up a MemoryQueue with a command resolver that dispatches across
    # all booted domain runtimes. Used by boot_multi to enable cross-domain
    # command dispatch via the queue.
    #
    #   include QueueWiring
    #   wire_queue(domains, runtimes)
    #
    module QueueWiring
      # Creates a global +Hecks.queue+ backed by a +MemoryQueue+ whose resolver
      # can find and dispatch any command across all booted domain runtimes.
      #
      # The resolver iterates through every runtime's aggregates looking for
      # one whose commands include the given command name. When found, it
      # resolves the command class via the domain module's constant hierarchy
      # (+ModuleDomain::AggregateName::Commands::CommandName+) and calls it.
      #
      # @param domains [Array<Hecks::DomainModel::Domain>] the list of domain definitions
      #   (currently unused but passed for symmetry with other wiring methods)
      # @param runtimes [Array<Hecks::Runtime>] the list of booted runtime instances
      #   to search for matching commands
      # @return [void]
      # @raise [Hecks::Error] if no runtime contains a matching command
      def wire_queue(domains, runtimes)
        Hecks.queue = Queue::MemoryQueue.new(
          command_resolver: ->(cmd_name, attrs) {
            runtimes.each do |rt|
              rt.domain.aggregates.each do |agg|
                next unless agg.commands.any? { |c| c.name == cmd_name }
                mod = Object.const_get(DomainNaming.domain_module_name(domain.name))
                klass = mod.const_get(agg.name).const_get(:Commands).const_get(cmd_name)
                return klass.call(**attrs)
              end
            end
            raise Hecks::Error, "Command not found: #{cmd_name}"
          }
        )
      end
    end
  end
end
