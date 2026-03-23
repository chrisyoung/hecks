# Hecks::Services::AggregateWiring
#
# Orchestrates binding of mixins onto aggregate classes. Each concern
# is a separate module with a .bind class method. AggregateWiring
# just resolves the class and delegates to each mixin.
module Hecks
  module Services
    class AggregateWiring
      def initialize(domain, repositories, command_bus, mod, port_name: nil)
        @domain = domain
        @repositories = repositories
        @command_bus = command_bus
        @mod = mod
        @port_name = port_name
      end

      def wire!
        @domain.aggregates.each do |agg|
          wire_aggregate(agg)
        end
      end

      private

      def wire_aggregate(agg)
        agg_class = @mod.const_get(Hecks::Utils.sanitize_constant(agg.name))
        repo = @repositories[agg.name]
        defaults = build_defaults(agg)

        Persistence.bind(agg_class, agg, repo)
        Commands.bind(agg_class, agg, @command_bus, repo, defaults)
        Querying.bind(agg_class, agg)
        Introspection.bind(agg_class, agg)
        wire_query_objects(agg, agg_class)
        PortEnforcer.new(port_name: @port_name).enforce!(agg, agg_class)
      end

      def build_defaults(agg)
        agg.attributes.each_with_object({}) { |attr, h| h[attr.name] = attr.list? ? [] : nil }
      end

      def wire_query_objects(agg, agg_class)
        repo = @repositories[agg.name]
        agg.queries.each do |query|
          method_name = Hecks::Utils.underscore(query.name).to_sym
          query_block = query.block
          agg_class.define_singleton_method(method_name) do |*args|
            builder = Querying::QueryBuilder.new(repo)
            builder.instance_exec(*args, &query_block)
          end
        end
      end
    end
  end
end
