# Hecks::Services::CommandWiring
#
# Wires command methods (create and update) onto aggregate classes. Extracted
# from AggregateWiring to keep file sizes manageable. Commands dispatch through
# the CommandBus and persist aggregates via the repository.
#
#   Pizza.create(name: "Margherita")    # from CreatePizza command
#   Order.place(pizza_id: id, quantity: 3)  # from PlaceOrder command
#
module Hecks
  module Services
    module CommandWiring
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
    end
  end
end
