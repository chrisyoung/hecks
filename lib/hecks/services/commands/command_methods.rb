# Hecks::Services::Commands::CommandMethods
#
# Binds command methods onto aggregate classes. Commands dispatch through
# the CommandBus and persist aggregates via the repository.
#
#   Commands.bind(PizzaClass, pizza_aggregate, bus, repo, defaults)
#   Pizza.create(name: "Margherita")
#   Order.place(pizza_id: id, quantity: 3)
#
module Hecks
  module Services
    module Commands
      module CommandMethods
      def self.bind(klass, aggregate, bus, repo, defaults)
        agg_snake = Hecks::Utils.underscore(aggregate.name)
        aggregate.commands.each do |cmd|
          full_name = Hecks::Utils.underscore(cmd.name)
          method_name = full_name.sub(/_#{agg_snake}$/, "").to_sym

          if cmd.name.start_with?("Create")
            bind_create(klass, method_name, cmd, bus, repo, defaults)
          else
            bind_update(klass, method_name, cmd, bus, repo, defaults)
          end
        end
      end

      def self.bind_create(klass, method_name, cmd, bus, repo, defaults)
        cmd_handler = cmd.handler
        agg_type = klass.name.split("::").last
        klass.define_singleton_method(method_name) do |**attrs|
          if cmd_handler
            require "ostruct"
            cmd_handler.call(OpenStruct.new(**attrs))
          end
          event = bus.dispatch(cmd.name, **attrs)
          now = Time.now
          constructor_attrs = { created_at: now, updated_at: now }
          defaults.each { |param, default_val| constructor_attrs[param] = attrs.key?(param) ? attrs[param] : default_val }
          aggregate = new(**constructor_attrs)
          repo.save(aggregate)
          recorder = respond_to?(:__hecks_event_recorder__) ? __hecks_event_recorder__ : nil
          recorder.record(agg_type, aggregate.id, event) if recorder
          aggregate
        end
      end

      def self.bind_update(klass, method_name, cmd, bus, repo, defaults)
        cmd_handler = cmd.handler
        agg_type = klass.name.split("::").last
        klass.define_singleton_method(method_name) do |**attrs|
          if cmd_handler
            require "ostruct"
            cmd_handler.call(OpenStruct.new(**attrs))
          end
          event = bus.dispatch(cmd.name, **attrs)
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
          recorder = respond_to?(:__hecks_event_recorder__) ? __hecks_event_recorder__ : nil
          recorder.record(agg_type, aggregate.id, event) if recorder
          aggregate
        end
      end
      end
    end
  end
end
