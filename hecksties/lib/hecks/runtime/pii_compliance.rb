# Hecks::PIICompliance
#
# Introspection module that produces a PII compliance report from the
# hecksagon's aggregate capabilities. Lists which aggregates contain
# PII-tagged attributes and which specific attributes are affected.
#
#   report = Hecks::PIICompliance.report(hecksagon, domain)
#   # => { "Customer" => ["email", "ssn"] }
#
module Hecks
  module PIICompliance
    # Generate a PII compliance report mapping aggregate names to their
    # PII-tagged attribute names.
    #
    # @param hecksagon [Hecksagon::Structure::Hecksagon] the hecksagon IR
    # @param domain [Hecks::DomainModel::Domain] the domain IR
    # @return [Hash{String => Array<String>}] aggregate name to PII attribute names
    def self.report(hecksagon, domain)
      result = {}
      domain.aggregates.each do |agg|
        pii_attrs = hecksagon.pii_attributes(agg.name)
        result[agg.name] = pii_attrs unless pii_attrs.empty?
      end
      result
    end

    # Register pii_report on the runtime for easy introspection.
    #
    # @param runtime [Hecks::Runtime] the runtime instance
    # @param hecksagon [Hecksagon::Structure::Hecksagon] the hecksagon IR
    # @param domain [Hecks::DomainModel::Domain] the domain IR
    # @return [void]
    def self.bind(runtime, hecksagon, domain)
      pii_data = report(hecksagon, domain)
      runtime.define_singleton_method(:pii_report) { pii_data }
    end
  end
end
