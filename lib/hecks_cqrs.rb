# HecksCqrs
#
# CQRS support for Hecks domains. Enables named persistence connections
# for read/write separation. Commands route to :write, queries to :read.
# Registers with the Hecks connection registry so domains can declare
# multiple named adapters in their boot block.
#
#   CatsDomain.boot do
#     persist_to :write, :sqlite
#     persist_to :read, :sqlite, database: "read.db"
#   end
#
#   # Access named connections:
#   CatsDomain.connections[:persist][:write]
#   # => { type: :sqlite }
#   CatsDomain.connections[:persist][:read]
#   # => { type: :sqlite, database: "read.db" }
#
require "hecks"

module HecksCqrs
  VERSION = "2026.03.24.1"

  # Check whether a domain module has CQRS connections configured.
  # True when more than one named persist connection exists.
  #
  # @param mod [Module] a domain module with DomainConnections
  # @return [Boolean]
  def self.active?(mod)
    return false unless mod.respond_to?(:connections)

    persist = mod.connections[:persist]
    persist.is_a?(Hash) && persist.size > 1
  end

  # Return the adapter config for a named connection, or nil.
  #
  # @param mod [Module] a domain module with DomainConnections
  # @param name [Symbol] connection name (:write, :read, :default)
  # @return [Hash, nil]
  def self.connection_for(mod, name)
    return nil unless mod.respond_to?(:connections)

    persist = mod.connections[:persist]
    persist[name] if persist.is_a?(Hash)
  end
end

# Register with Hecks connection registry if available
if defined?(Hecks) && Hecks.respond_to?(:extension_registry)
  Hecks.extension_registry[:cqrs] = HecksCqrs
end
