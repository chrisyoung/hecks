# = HecksContracts
#
# Contract registry and contract definitions.
#
module HecksTemplating; end  # ensure namespace exists

module Hecks
  module Contracts
    @registry = {}
    def self.register(name, contract) = @registry[name.to_sym] = contract
    def self.for(name) = @registry[name.to_sym]
    def self.registered = @registry.keys
  end
end

# Load all contract files
Dir[File.join(__dir__, "hecks_contracts", "*.rb")].sort.each { |f| require f }

# Register them
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
