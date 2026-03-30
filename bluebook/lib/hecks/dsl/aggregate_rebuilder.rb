# Hecks::DSL::AggregateRebuilder
#
# Reconstructs an AggregateBuilder from a built Aggregate model object.
# Used when loading an existing domain.rb and needing to work with builder
# objects (e.g., in the interactive console session or DslSerializer round-trips).
# Restores attributes, value objects, commands, validations, scopes, and
# reactive policies. Does not restore ports, queries, or guard policies.
#
#   builder = DSL::AggregateRebuilder.from_aggregate(aggregate)
#   builder.build  # => a new Aggregate equivalent to the original
#
module Hecks
  module DSL
    # Reconstructs an AggregateBuilder from a previously built Aggregate IR object.
    #
    # AggregateRebuilder provides a single class method, +.from_aggregate+, that
    # takes a +DomainModel::Structure::Aggregate+ and produces an +AggregateBuilder+
    # pre-populated with equivalent DSL declarations. This enables round-trip
    # serialization (build -> serialize -> deserialize -> rebuild) and is used by
    # the interactive session/playground when loading saved domain definitions.
    #
    # Supported facets: attributes (including list and reference types), value
    # objects, entities, commands (with their attributes), validations, scopes,
    # reactive policies, and specifications.
    #
    # Not restored: ports, queries, guard policies (block-based policies),
    # invariants, event subscribers, indexes, lifecycle, versioned/attachable flags.
    class AggregateRebuilder
      # Reconstruct an AggregateBuilder from a built Aggregate IR object.
      #
      # Iterates over the aggregate's attributes, value objects, entities,
      # commands, validations, scopes, reactive policies, and specifications,
      # calling the corresponding DSL methods on a fresh AggregateBuilder.
      #
      # List and reference attributes are automatically wrapped in the
      # appropriate +{ list: type }+ or +{ reference: type }+ hash form
      # so that +AttributeCollector#attribute+ handles them correctly.
      #
      # @param aggregate [DomainModel::Structure::Aggregate] the aggregate IR to reconstruct from
      # @return [AggregateBuilder] a builder pre-populated with equivalent declarations
      def self.from_aggregate(aggregate)
        builder = DSL::AggregateBuilder.new(aggregate.name)
        aggregate.attributes.each do |attr|
          type = if attr.list?
                   { list: attr.type }
                 elsif attr.reference?
                   { reference: attr.type }
                 else
                   attr.type
                 end
          builder.attribute(attr.name, type)
        end
        aggregate.value_objects.each do |vo|
          builder.value_object(vo.name) do
            vo.attributes.each do |attr|
              type = if attr.list?
                       { list: attr.type }
                     elsif attr.reference?
                       { reference: attr.type }
                     else
                       attr.type
                     end
              attribute attr.name, type
            end
          end
        end
        aggregate.entities.each do |ent|
          builder.entity(ent.name) do
            ent.attributes.each do |attr|
              type = if attr.list?
                       { list: attr.type }
                     elsif attr.reference?
                       { reference: attr.type }
                     else
                       attr.type
                     end
              attribute attr.name, type
            end
          end
        end
        aggregate.commands.each do |cmd|
          builder.command(cmd.name) do
            cmd.attributes.each do |attr|
              type = if attr.list?
                       { list: attr.type }
                     elsif attr.reference?
                       { reference: attr.type }
                     else
                       attr.type
                     end
              attribute attr.name, type
            end
          end
        end
        aggregate.validations.each do |v|
          builder.validation(v.field, v.rules)
        end
        aggregate.scopes.each do |s|
          builder.scope(s.name, s.conditions)
        end
        aggregate.policies.each do |pol|
          builder.policy(pol.name) do
            on pol.event_name
            trigger pol.trigger_command
          end
        end
        aggregate.specifications.each do |spec|
          builder.specification(spec.name, &spec.block)
        end
        builder
      end
    end
  end
end
