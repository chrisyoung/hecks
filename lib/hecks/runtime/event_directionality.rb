# Hecks::Boot::EventDirectionality
#
# Introspects reactive policies across multiple domains to build a
# directionality map — which domains each domain needs to listen to.
# Used by boot_multi to create FilteredEventBus instances and by
# auto_wire to keep explicit config consistent with introspected wiring.
#
#   map = EventDirectionality.build(domains)
#   # => { "identity_domain" => ["model_registry_domain", "operations_domain"] }
#
module Hecks
  module Boot
    module EventDirectionality
      # Build a map of gem_name -> array of source gem_names this domain
      # needs events from, based on reactive policy introspection.
      def self.build(domains)
        event_origins = {}
        domains.each do |d|
          d.aggregates.each do |agg|
            agg.events.each { |e| event_origins[e.name] = d.gem_name }
          end
        end

        listeners = {}
        domains.each do |d|
          all_policies = d.aggregates.flat_map(&:policies) + (d.policies || [])
          all_policies.select(&:reactive?).each do |pol|
            source = event_origins[pol.event_name]
            next unless source && source != d.gem_name
            listeners[d.gem_name] ||= []
            listeners[d.gem_name] << source unless listeners[d.gem_name].include?(source)
          end
        end

        listeners
      end

      # Validate that explicit declarations match what policies actually need.
      # Returns an array of warning strings (empty if everything matches).
      def self.validate(domains, declarations)
        warnings = []
        introspected = build(domains)

        introspected.each do |gem_name, needed_sources|
          declared = declarations[gem_name]
          next unless declared # no declarations = open mode, skip

          needed_sources.each do |source|
            unless declared.include?(source)
              warnings << "#{gem_name} has policies reacting to #{source} events but does not declare listens_to \"#{source}\""
            end
          end
        end

        warnings
      end
    end
  end
end
