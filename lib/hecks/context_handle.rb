# Hecks::ContextHandle
#
# Interactive handle for building a bounded context in the REPL. Returns
# AggregateHandles for each aggregate within the context.
#
#   session = Hecks.session("Pizzas")
#   ordering = session.context("Ordering")
#   order = ordering.aggregate("Order")
#   order.add_attribute :quantity, Integer
#
#   ordering.describe
#   ordering.aggregates  # => ["Order"]
#
module Hecks
  class ContextHandle
    attr_reader :name

    def initialize(name, context_builder, domain_module:)
      @name = name
      @context_builder = context_builder
      @domain_module = domain_module
      @handles = {}
    end

    def aggregate(name, &block)
      # Delegate to the context builder's aggregate method
      @context_builder.aggregate(name, &block) if block

      # Ensure we have a builder for this aggregate
      builders = @context_builder.aggregates
      # The context builder stores built aggregates, so we need an AggregateBuilder for the handle
      unless @handles[name]
        agg_builder = DSL::AggregateBuilder.new(name)
        @handles[name] = AggregateHandle.new(name, agg_builder, domain_module: "#{@domain_module}::#{@name}")
      end

      handle = @handles[name]

      if block
        agg = builders.last
        puts "#{@name}::#{name} (#{aggregate_summary(agg)})"
      end

      handle
    end

    def aggregates
      @handles.keys
    end

    def describe
      ctx = @context_builder.build
      lines = []
      lines << "#{@name} Context"
      lines << ""

      ctx.aggregates.each do |agg|
        lines << "  #{agg.name}"

        unless agg.attributes.empty?
          attrs = agg.attributes.map { |a| "#{a.name} (#{Hecks::Utils.type_label(a)})" }.join(", ")
          lines << "    Attributes: #{attrs}"
        end

        unless agg.commands.empty?
          agg.commands.each_with_index do |cmd, i|
            event = agg.events[i]
            lines << "    Commands: #{cmd.name} -> #{event&.name}"
          end
        end

        unless agg.policies.empty?
          agg.policies.each do |pol|
            lines << "    Policies: #{pol.name} (on #{pol.event_name} -> #{pol.trigger_command})"
          end
        end

        lines << ""
      end

      puts lines.join("\n")
      nil
    end

    def remove(aggregate_name)
      @handles.delete(aggregate_name)
      puts "Removed #{@name}::#{aggregate_name}"
      self
    end

    def inspect
      "#<#{@name} Context (#{@handles.size} aggregates)>"
    end

    private

    def aggregate_summary(agg)
      parts = []
      parts << "#{agg.attributes.size} attributes" unless agg.attributes.empty?
      parts << "#{agg.commands.size} commands" unless agg.commands.empty?
      parts.empty? ? "empty" : parts.join(", ")
    end

  end
end
