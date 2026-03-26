# Hecks::CLI::DomainIntrospector
#
# Analyzes cross-domain event wiring by introspecting reactive policies.
# Builds maps of which domains produce events consumed by other domains'
# policies, yielding listener (who I react to) and sender (who reacts to me)
# relationships. All map keys use gem_name (snake_case) for consistency.
#
#   introspector = DomainIntrospector.new(domains)
#   introspector.listeners   # { "identity_domain" => { "model_registry_domain" => [pol, ...] } }
#   introspector.senders     # { "model_registry_domain" => { "identity_domain" => [pol, ...] } }
#
module Hecks
  class CLI < Thor
    class DomainIntrospector
      attr_reader :listeners, :senders

      def initialize(domains)
        @gem_names = domains.each_with_object({}) { |d, h| h[d.name] = d.gem_name }
        origins = build_event_origin_map(domains)
        @listeners = build_listener_map(domains, origins)
        @senders = build_sender_map(@listeners)
      end

      private

      # Map event names to the gem_name of the domain that produces them.
      def build_event_origin_map(domains)
        origins = {}
        domains.each do |d|
          d.aggregates.each do |agg|
            agg.events.each { |e| origins[e.name] = d.gem_name }
          end
        end
        origins
      end

      # For each domain, find reactive policies that listen to events from
      # other domains. Keyed by gem_name.
      def build_listener_map(domains, event_origins)
        listeners = {}
        domains.each do |d|
          all_policies = d.aggregates.flat_map(&:policies) + (d.policies || [])
          all_policies.select(&:reactive?).each do |pol|
            source = event_origins[pol.event_name]
            next unless source && source != d.gem_name
            listeners[d.gem_name] ||= {}
            listeners[d.gem_name][source] ||= []
            listeners[d.gem_name][source] << pol
          end
        end
        listeners
      end

      # Invert the listener map: for each source domain, which target domains
      # consume its events?
      def build_sender_map(listeners)
        senders = {}
        listeners.each do |listener_gem, sources|
          sources.each do |source_gem, policies|
            senders[source_gem] ||= {}
            senders[source_gem][listener_gem] ||= []
            policies.each { |pol| senders[source_gem][listener_gem] << pol }
          end
        end
        senders
      end
    end
  end
end
