module Hecks
  module DSL

    # Hecks::DSL::ReferencePathParser
    #
    # Parses qualified reference_to paths into structured components. Handles
    # 1-segment (local), 2-segment (aggregate::entity or domain::aggregate),
    # and 3-segment (domain::aggregate::entity) paths.
    #
    # The 2-segment ambiguity (Aggregate::Entity vs Domain::Aggregate) is resolved
    # later by classify_references, which has access to the full domain model.
    #
    #   ReferencePathParser.parse(["Topping"])
    #   # => { type: "Topping" }
    #
    #   ReferencePathParser.parse(["Pizza", "Topping"])
    #   # => { type: "Topping", aggregate: "Pizza" }
    #
    #   ReferencePathParser.parse(["Ordering", "Pizza", "Topping"])
    #   # => { type: "Topping", aggregate: "Pizza", domain: "Ordering" }
    #
    module ReferencePathParser
      # Parse path segments into a hash of reference components.
      #
      # @param segments [Array<String>] 1-3 path segments
      # @return [Hash] with keys :type, and optionally :aggregate, :domain
      # @raise [ArgumentError] if more than 3 segments
      def self.parse(segments)
        case segments.length
        when 1
          { type: segments[0] }
        when 2
          { type: segments[1], aggregate: segments[0] }
        when 3
          { type: segments[2], aggregate: segments[1], domain: segments[0] }
        else
          raise ArgumentError,
            "reference_to path must have 1-3 segments (Type, Aggregate::Type, " \
            "or Domain::Aggregate::Type), got #{segments.length}: #{segments.join('::')}"
        end
      end
    end
  end
end
