# HecksBubble::Context
#
# A bubble context is an anti-corruption layer that isolates a domain from
# external naming conventions. It holds aggregate mappings and provides
# +translate+ (legacy -> domain) and +reverse+ (domain -> legacy) methods.
#
# Use +map_aggregate+ with a block to declare field mappings per aggregate.
# Then call +translate+ with the aggregate name, command verb, and legacy data
# to get clean domain data ready for command dispatch.
#
#   context = HecksBubble::Context.new
#   context.map_aggregate :Pizza do
#     from_legacy :pie_name, to: :name
#     from_legacy :pie_desc, to: :description
#   end
#
#   context.translate(:Pizza, :create, pie_name: "Margherita", pie_desc: "Classic")
#   # => { name: "Margherita", description: "Classic" }
#
#   context.reverse(:Pizza, name: "Margherita", description: "Classic")
#   # => { pie_name: "Margherita", pie_desc: "Classic" }
#
module HecksBubble
  class Context
    # @return [Hash<Symbol, AggregateMapping>] registered aggregate mappings
    attr_reader :mappings

    def initialize
      @mappings = {}
    end

    # Declare field mappings for an aggregate.
    #
    # @param aggregate_name [Symbol, String] the aggregate to map
    # @yield block evaluated in AggregateMapping context (use +from_legacy+)
    # @return [void]
    def map_aggregate(aggregate_name, &block)
      mapping = AggregateMapping.new(aggregate_name)
      mapping.instance_eval(&block) if block
      @mappings[aggregate_name.to_sym] = mapping
    end

    # Translate legacy data to domain data for a given aggregate and command.
    # The command_verb is informational (for logging/middleware) -- the actual
    # mapping is aggregate-level. Returns the data unchanged if no mapping exists.
    #
    # @param aggregate_name [Symbol, String] the target aggregate
    # @param command_verb [Symbol, String] the command verb (e.g. :create, :update)
    # @param data [Hash] legacy field names and values
    # @return [Hash] domain field names and values
    def translate(aggregate_name, command_verb, data)
      mapping = @mappings[aggregate_name.to_sym]
      return data unless mapping

      mapping.forward(data)
    end

    # Reverse-translate domain data back to legacy field names.
    #
    # @param aggregate_name [Symbol, String] the source aggregate
    # @param data [Hash] domain field names and values
    # @return [Hash] legacy field names and values
    def reverse(aggregate_name, data)
      mapping = @mappings[aggregate_name.to_sym]
      return data unless mapping

      mapping.reverse(data)
    end

    # List all aggregate names that have mappings registered.
    #
    # @return [Array<Symbol>] mapped aggregate names
    def mapped_aggregates
      @mappings.keys
    end
  end
end
