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
        @domain.contexts.each do |ctx|
          ctx.aggregates.each do |agg|
            wire_aggregate(ctx, agg)
          end
        end
      end

      private

      def wire_aggregate(ctx, agg)
        agg_class = resolve_aggregate_class(ctx, agg)
        repo_key = ctx.default? ? agg.name : "#{ctx.name}/#{agg.name}"
        repo = @repositories[repo_key]
        defaults = build_defaults(agg)

        Persistence.bind(agg_class, agg, repo)
        Commands.bind(agg_class, agg, @command_bus, repo, defaults)
        Querying.bind(agg_class, agg)
        wire_query_objects(agg, agg_class)
        PortEnforcer.new(port_name: @port_name).enforce!(agg, agg_class)
      end

      def build_defaults(agg)
        agg.attributes.each_with_object({}) { |attr, h| h[attr.name] = attr.list? ? [] : nil }
      end

      def wire_query_objects(agg, agg_class)
        agg.queries.each do |query|
          method_name = Hecks::Utils.underscore(query.name).to_sym
          query_block = query.block
          agg_class.define_singleton_method(method_name) do |*args|
            repo = instance_variable_get(:@__hecks_repo__)
            builder = Querying::QueryBuilder.new(repo)
            builder.instance_exec(*args, &query_block)
          end
        end
      end

      def resolve_aggregate_class(ctx, agg)
        ctx.default? ? @mod.const_get(agg.name) : @mod.const_get(ctx.module_name).const_get(agg.name)
      end
    end
  end
end
