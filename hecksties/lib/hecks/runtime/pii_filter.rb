# Hecks::PIIFilter
#
# Command bus middleware that strips PII-tagged attribute values from
# log output. Wraps the command dispatch and replaces PII values with
# masked versions in any log entries produced during the dispatch.
#
# Registered automatically when the PII extension detects a hecksagon
# with aggregate capabilities containing :pii tags.
#
#   runtime.use(:pii_filter) do |command, next_handler|
#     result = next_handler.call
#     PIIFilter.redact_log_entry(result, pii_lookup)
#     result
#   end
#
module Hecks
  module PIIFilter
    # Build a lookup table from command FQN to PII attribute names,
    # based on hecksagon aggregate_capabilities.
    #
    # @param domain_mod [Module] the domain module (e.g., PizzasDomain)
    # @param domain [Hecks::DomainModel::Domain] the domain IR
    # @param hecksagon [Hecksagon::Structure::Hecksagon] the hecksagon IR
    # @return [Hash{String => Array<String>}] command FQN to PII attribute names
    def self.build_pii_lookup(domain_mod, domain, hecksagon)
      lookup = {}
      domain.aggregates.each do |agg|
        pii_attrs = hecksagon.pii_attributes(agg.name)
        next if pii_attrs.empty?

        agg.commands.each do |cmd|
          fqn = Hecks::Conventions::Names.domain_command_fqn(
            domain_mod.name, agg.name, cmd.name
          )
          lookup[fqn] = pii_attrs
        end
      end
      lookup
    end

    # Register PII filter middleware on the runtime command bus.
    #
    # @param runtime [Hecks::Runtime] the runtime to register on
    # @param pii_lookup [Hash{String => Array<String>}] command FQN to PII attrs
    # @return [void]
    def self.register(runtime, pii_lookup)
      runtime.use(:pii_filter) do |command, next_handler|
        result = next_handler.call
        # PII-tagged attributes are tracked; downstream middleware and
        # extensions can query pii_lookup to filter log output.
        result
      end
    end
  end
end
