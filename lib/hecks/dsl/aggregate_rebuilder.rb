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
    class AggregateRebuilder
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
              attribute attr.name, attr.type
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
        builder
      end
    end
  end
end
