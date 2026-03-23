# Hecks::Services::AggregateWiring
#
# Wires aggregate classes with domain behavior: DSL query objects, commands,
# collection proxies, reference resolution, and scopes. Persistence methods
# (find, save, where, etc.) are opt-in via RepositoryMethods.bind.
module Hecks
  module Services
    class AggregateWiring
      include CommandWiring

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
        bus = @command_bus
        repo_key = ctx.default? ? agg.name : "#{ctx.name}/#{agg.name}"
        repo = @repositories[repo_key]
        defaults = build_defaults(agg)
        RepositoryMethods.bind(agg_class, repo)
        wire_collection_proxies(agg, agg_class, repo)
        wire_query_objects(agg, agg_class)
        wire_references(agg, agg_class)
        wire_commands(agg, agg_class, bus, repo, defaults)
        wire_scopes(agg, agg_class)
        PortEnforcer.new(port_name: @port_name).enforce!(agg, agg_class)
      end

      def build_defaults(agg)
        agg.attributes.each_with_object({}) { |attr, h| h[attr.name] = attr.list? ? [] : nil }
      end
      def wire_collection_proxies(agg, agg_class, repo)
        agg.attributes.select(&:list?).each do |list_attr|
          vo = agg.value_objects.find { |v| v.name == list_attr.type.to_s }
          next unless vo
          attr_name = list_attr.name
          vo_class = agg_class.const_get(vo.name) rescue nil
          next unless vo_class
          repo_ref = repo
          agg_class.define_method(attr_name) do
            items = instance_variable_get(:"@#{attr_name}") || []
            CollectionProxy.new(items: items, owner: self, attr_name: attr_name,
                                value_object_class: vo_class, repo: repo_ref)
          end
        end
      end
      def wire_query_objects(agg, agg_class)
        agg.queries.each do |query|
          method_name = Hecks::Utils.underscore(query.name).to_sym
          query_block = query.block
          agg_class.define_singleton_method(method_name) do |*args|
            repo = instance_variable_get(:@__hecks_repo__)
            builder = QueryBuilder.new(repo)
            builder.instance_exec(*args, &query_block)
          end
        end
      end
      def wire_references(agg, agg_class)
        agg.attributes.select(&:reference?).each do |ref_attr|
          method_name_for_ref = ref_attr.name.to_s.sub(/_id$/, "").to_sym
          ref_type = ref_attr.type.to_s

          agg_class.define_method(method_name_for_ref) do
            ref_id = send(ref_attr.name)
            return nil unless ref_id
            Object.const_get(ref_type).find(ref_id) rescue nil
          end
        end
      end
      def wire_commands(agg, agg_class, bus, repo, defaults)
        agg_snake = Hecks::Utils.underscore(agg.name)
        agg.commands.each do |cmd|
          full_name = Hecks::Utils.underscore(cmd.name)
          method_name = full_name.sub(/_#{agg_snake}$/, "").to_sym
          is_create = cmd.name.start_with?("Create")

          if is_create
            wire_create_command(agg_class, method_name, cmd, bus, repo, defaults)
          else
            wire_update_command(agg_class, method_name, cmd, bus, repo, defaults)
          end
        end
      end
      def wire_scopes(agg, agg_class)
        agg.scopes.each do |scope|
          if scope.callable?
            agg_class.define_singleton_method(scope.name) do |*args|
              conditions = scope.conditions.call(*args)
              QueryBuilder.new(instance_variable_get(:@__hecks_repo__)).where(**conditions)
            end
          else
            agg_class.define_singleton_method(scope.name) do
              QueryBuilder.new(instance_variable_get(:@__hecks_repo__)).where(**scope.conditions)
            end
          end
        end
      end
      def resolve_aggregate_class(ctx, agg)
        ctx.default? ? @mod.const_get(agg.name) : @mod.const_get(ctx.module_name).const_get(agg.name)
      end
    end
  end
end
