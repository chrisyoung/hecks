# Hecks::Boot::QueueWiring
#
# Wires up a MemoryQueue with a command resolver that dispatches across
# all booted domain runtimes. Used by boot_multi to enable cross-domain
# command dispatch via the queue.
#
#   include QueueWiring
#   wire_queue(domains, runtimes)
#
module Hecks
  module Boot
    module QueueWiring
      def wire_queue(domains, runtimes)
        Hecks.queue = Queue::MemoryQueue.new(
          command_resolver: ->(cmd_name, attrs) {
            runtimes.each do |rt|
              rt.domain.aggregates.each do |agg|
                next unless agg.commands.any? { |c| c.name == cmd_name }
                mod = Object.const_get(rt.domain.module_name + "Domain")
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
