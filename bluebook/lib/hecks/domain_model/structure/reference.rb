module Hecks
  module DomainModel
    module Structure

    # Hecks::DomainModel::Structure::Reference
    #
    # Represents a relationship from one aggregate to another. References are
    # first-class domain concepts — the domain layer holds live objects in memory,
    # never foreign key IDs. Persistence is the only layer that knows about IDs.
    #
    # The +kind+ is set post-build by DomainBuilder#classify_references:
    #   :composition    — target is a VO/entity within the same aggregate
    #   :aggregation    — target is another aggregate root
    #   :cross_context  — target is in a different bounded context
    #
    # Qualified paths support 1, 2, or 3 segments:
    #   reference_to "Topping"                     — 1 segment, local lookup
    #   reference_to "Pizza::Topping"              — 2 segments, aggregate::entity
    #   reference_to "Ordering::Pizza::Topping"    — 3 segments, domain::aggregate::entity
    #
    #   ref = Reference.new(name: :team, type: "Team")
    #   ref = Reference.new(name: :topping, type: "Topping", aggregate: "Pizza")
    #   ref = Reference.new(name: :invoice, type: "Invoice", domain: "Billing")
    #
    class Reference
      # @return [Symbol] the role name (e.g., :team, :home_team)
      attr_reader :name

      # @return [String] the leaf type name (e.g., "Team", "Topping")
      attr_reader :type

      # @return [String, nil] the domain name for cross-context references
      attr_reader :domain

      # @return [String, nil] the target aggregate name for qualified refs
      attr_reader :aggregate

      # @return [Array<String>] raw path segments from the DSL declaration
      attr_reader :segments

      # @return [Symbol, nil] the relationship kind, set by classify_references
      attr_accessor :kind

      # @return [Symbol, Boolean] validation mode — true/:exists checks existence,
      #   false skips validation entirely (opt-out for eventual consistency)
      attr_reader :validate

      def initialize(name:, type:, domain: nil, aggregate: nil, kind: nil, validate: true, segments: nil)
        @name = name.to_sym
        @type = type.to_s
        @domain = domain
        @aggregate = aggregate
        @kind = kind
        @validate = validate
        @segments = segments || build_segments
      end

      # Returns true if this is a cross-context reference.
      def cross_context?
        kind == :cross_context
      end

      # Returns the fully qualified path string (e.g., "Ordering::Pizza::Topping").
      def qualified_path
        segments.join("::")
      end

      private

      def build_segments
        parts = []
        parts << @domain if @domain
        parts << @aggregate if @aggregate
        parts << @type
        parts
      end
    end
    end
  end
end
