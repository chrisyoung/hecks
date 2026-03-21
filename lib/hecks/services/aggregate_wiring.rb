# Hecks::Services::AggregateWiring
#
# Wires aggregate classes with repository-backed class/instance methods,
# reference resolution, collection proxies, scopes, and command methods.
# Routes commands through the CommandBus (with middleware support) and
# enforces port-based access restrictions when a port is specified.
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
        bus = @command_bus
        repo_key = ctx.default? ? agg.name : "#{ctx.name}/#{agg.name}"
        repo = @repositories[repo_key]
        defaults = build_defaults(agg)
        wire_collection_proxies(agg, agg_class, repo)
        wire_repository_class_methods(agg, agg_class, repo, defaults)
        wire_query_methods(agg_class)
        wire_instance_methods(agg_class, repo)
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
      def wire_repository_class_methods(agg, agg_class, repo, defaults)
        agg_class.define_singleton_method(:find) { |id| repo.find(id) }
        agg_class.define_singleton_method(:all) { repo.all }
        agg_class.define_singleton_method(:count) { repo.count }
        agg_class.define_singleton_method(:delete) { |id| repo.delete(id) }

        unless agg.commands.any? { |c| c.name.start_with?("Create") }
          defaults_for_create = defaults
          agg_class.define_singleton_method(:create) do |**attrs|
            now = Time.now
            constructor_attrs = { created_at: now, updated_at: now }
            defaults_for_create.each do |param, default_val|
              constructor_attrs[param] = attrs.key?(param) ? attrs[param] : default_val
            end
            aggregate = new(**constructor_attrs)
            repo.save(aggregate)
            aggregate
          end
        end
      end
      def wire_query_methods(agg_class)
        agg_class.define_singleton_method(:where) do |**conditions|
          all.select do |obj|
            conditions.all? { |k, v| obj.respond_to?(k) && obj.send(k) == v }
          end
        end
        agg_class.define_singleton_method(:first) { all.first }
        agg_class.define_singleton_method(:last) { all.last }
      end
      def wire_instance_methods(agg_class, repo)
        agg_class.define_method(:save) { repo.save(self); self }
        agg_class.define_method(:destroy) { repo.delete(id); self }
        agg_class.define_method(:update) do |**new_attrs|
          constructor_attrs = { id: id, created_at: (created_at if respond_to?(:created_at)), updated_at: Time.now }
          self.class.instance_method(:initialize).parameters.each do |_, param_name|
            next unless param_name
            next if param_name == :id || param_name == :created_at || param_name == :updated_at
            constructor_attrs[param_name] = new_attrs.key?(param_name) ? new_attrs[param_name] : send(param_name) if respond_to?(param_name)
          end
          updated = self.class.new(**constructor_attrs)
          repo.save(updated)
          updated
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
      def wire_create_command(agg_class, method_name, cmd, bus, repo, defaults)
        cmd_handler = cmd.handler
        agg_class.define_singleton_method(method_name) do |**attrs|
          if cmd_handler
            require "ostruct"
            cmd_handler.call(OpenStruct.new(**attrs))
          end
          bus.dispatch(cmd.name, **attrs)
          now = Time.now
          constructor_attrs = { created_at: now, updated_at: now }
          defaults.each { |param, default_val| constructor_attrs[param] = attrs.key?(param) ? attrs[param] : default_val }
          aggregate = new(**constructor_attrs)
          repo.save(aggregate)
          aggregate
        end
      end
      def wire_update_command(agg_class, method_name, cmd, bus, repo, defaults)
        cmd_handler = cmd.handler
        agg_class.define_singleton_method(method_name) do |**attrs|
          if cmd_handler
            require "ostruct"
            cmd_handler.call(OpenStruct.new(**attrs))
          end
          bus.dispatch(cmd.name, **attrs)
          id_key = attrs.keys.find { |k| k.to_s.end_with?("_id") }
          existing = id_key ? repo.find(attrs[id_key]) : nil
          if existing
            now = Time.now
            constructor_attrs = {
              id: existing.id,
              created_at: (existing.created_at if existing.respond_to?(:created_at)),
              updated_at: now
            }
            defaults.each do |param, default_val|
              if attrs.key?(param)
                constructor_attrs[param] = attrs[param]
              elsif existing.respond_to?(param)
                constructor_attrs[param] = existing.send(param)
              else
                constructor_attrs[param] = default_val
              end
            end
            aggregate = new(**constructor_attrs)
          else
            now = Time.now
            constructor_attrs = { created_at: now, updated_at: now }
            defaults.each { |param, default_val| constructor_attrs[param] = attrs.key?(param) ? attrs[param] : default_val }
            aggregate = new(**constructor_attrs)
          end

          repo.save(aggregate)
          aggregate
        end
      end
      def wire_scopes(agg, agg_class)
        agg.scopes.each do |scope|
          if scope.callable?
            agg_class.define_singleton_method(scope.name) do |*args|
              conditions = scope.conditions.call(*args)
              where(**conditions)
            end
          else
            agg_class.define_singleton_method(scope.name) do
              where(**scope.conditions)
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
