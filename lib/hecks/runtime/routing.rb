require_relative "errors"
require_relative "refusal_wording"

module Hecks
  module Runtime
    # The invocation address is not part of a command's domain payload.
    # Aggregate commands carry one receiver identity; entity commands carry
    # the aggregate receiver followed by one identity for every entity hop.
    module Routing
      Envelope = Struct.new(:aggregate, :entities, keyword_init: true) do
        def initialize(aggregate:, entities: [])
          super(aggregate: aggregate.to_s, entities: Array(entities).map(&:to_s).freeze)
          freeze
        end
      end

      module_function

      def envelope(to, entity_depth: 0)
        return nil if to.nil?

        aggregate, entities = if to.is_a?(Hash)
                                hash = to.transform_keys(&:to_sym)
                                unknown = hash.keys - %i[aggregate entity entities]
                                raise TypeMismatch, "to: does not recognize #{unknown.sort.join(', ')}" unless unknown.empty?

                                [hash[:aggregate], entity_identities(hash)]
                              else
                                [to, []]
                              end

        raise TypeMismatch, "to: must name the receiving aggregate identity" if aggregate.nil? || aggregate.to_s.empty?
        if entities.size != entity_depth
          raise TypeMismatch,
                "to: for an entity command needs #{entity_depth} entity " \
                "#{entity_depth == 1 ? 'identity' : 'identities'} after the aggregate — got #{entities.size}"
        end
        raise TypeMismatch, "to: contains a blank entity identity" if entities.any? do |identity|
          identity.nil? || identity.to_s.empty?
        end

        Envelope.new(aggregate: aggregate, entities: entities)
      end

      # `with:` is deliberately strict. Compatibility-only calls still pass
      # loose keyword arguments through the old addressing gate, but a caller
      # choosing the explicit envelope cannot smuggle receiver identity back
      # into the payload.
      def payload(command, with:, legacy:)
        if with && !legacy.empty?
          raise TypeMismatch,
                "dispatch takes command facts in with:, not both with: and loose keyword arguments"
        end

        return legacy unless with
        raise TypeMismatch, "with: must be a hash of command facts" unless with.is_a?(Hash)

        offered = with.transform_keys(&:to_sym)
        declared = command.attributes.map { |attribute| attribute.name.to_sym }
        unknown = (offered.keys - declared).sort
        unless unknown.empty?
          reading = declared.empty? ? "none" : declared.join(", ")
          raise UnknownArgument,
                RefusalWording.render("UnknownArgument", "unknown_args",
                                      command: command.hecks_name, unknown: unknown.join(", "),
                                      declared: reading)
        end

        absent = command.attributes.reject(&:optional?).map { |attribute| attribute.name.to_sym } - offered.keys
        unless absent.empty?
          reading = declared.empty? ? "none" : declared.join(", ")
          raise AbsentArgument,
                RefusalWording.render("AbsentArgument", "absent_args",
                                      command: command.hecks_name, absent: absent.sort.join(", "),
                                      declared: reading)
        end

        offered
      end

      def entity_identities(hash)
        raise TypeMismatch, "to: takes entity: or entities:, not both" if hash.key?(:entities) && hash.key?(:entity)

        hash.key?(:entities) ? Array(hash[:entities]) : Array(hash[:entity])
      end
      private_class_method :entity_identities
    end
  end
end
