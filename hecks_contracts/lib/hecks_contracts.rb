# = HecksContracts
#
# Contract registry. Each contract registers itself here.
# Generators query by name: Hecks::Contracts.for(:types)
#
# Targets register on existing contracts:
#   HecksTemplating::TypeContract.register_target(:java, { "String" => "String" })
#
module Hecks
  module Contracts
    @registry = {}

    def self.register(name, contract)
      @registry[name.to_sym] = contract
    end

    def self.for(name)
      @registry[name.to_sym]
    end

    def self.registered
      @registry.keys
    end
  end
end

# Register all built-in contracts (hecks_templating loaded before us)
Hecks::Contracts.register(:types,      HecksTemplating::TypeContract)
Hecks::Contracts.register(:display,    HecksTemplating::DisplayContract)
Hecks::Contracts.register(:views,      HecksTemplating::ViewContract)
Hecks::Contracts.register(:events,     HecksTemplating::EventContract)
Hecks::Contracts.register(:event_log,  HecksTemplating::EventLogContract)
Hecks::Contracts.register(:forms,      HecksTemplating::FormParsingContract)
Hecks::Contracts.register(:aggregates, HecksTemplating::AggregateContract)
Hecks::Contracts.register(:naming,     HecksTemplating::Names)
Hecks::Contracts.register(:migrations, HecksTemplating::MigrationContract)
Hecks::Contracts.register(:ui_labels,  HecksTemplating::UILabelContract)
