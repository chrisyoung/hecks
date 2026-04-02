# = Hecks::Events::BuildEngine
#
# Factory method that builds an UpcasterEngine from a domain's
# upcaster declarations. Reads the domain IR's upcasters array
# and registers each transform in a fresh UpcasterRegistry.
#
#   engine = Hecks::Events::BuildEngine.call(domain)
#   engine.upcast("CreatedPizza", data: old_data, from_version: 1, to_version: 2)
#
module Hecks
  module Events
    module BuildEngine
      # Build an UpcasterEngine from the domain's upcaster declarations.
      #
      # @param domain [Hecks::DomainModel::Structure::Domain] the domain IR
      # @return [Hecks::Events::UpcasterEngine] a wired engine
      def self.call(domain)
        registry = UpcasterRegistry.new
        (domain.upcasters || []).each do |decl|
          registry.register(decl.event_type, from: decl.from, to: decl.to, &decl.transform)
        end
        UpcasterEngine.new(registry)
      end
    end
  end
end
