module Hecksagon
  module DSL

    # Hecksagon::DSL::TagApplier
    #
    # Chainable tag applicator for attribute capabilities. Concern names
    # (like +.privacy+) expand into multiple tags via CONCERN_MAP. Individual
    # tags can also be applied directly.
    #
    #   applier = TagApplier.new("email", tags_hash)
    #   applier.privacy          # adds [:pii, :encrypted, :masked]
    #   applier.privacy.searchable  # adds :searchable too
    #
    class TagApplier
      # Maps concern names to the tags they expand into.
      CONCERN_MAP = {
        privacy: %i[pii encrypted masked],
      }.freeze

      # @param attribute_name [String] the attribute being tagged
      # @param tags_store [Hash{String => Array<Symbol>}] shared store of all attribute tags
      def initialize(attribute_name, tags_store)
        @attribute_name = attribute_name
        @tags_store = tags_store
      end

      # Apply a concern or individual tag. Concerns expand via CONCERN_MAP;
      # unknown names are treated as individual tags.
      #
      # @return [self] for chaining
      def method_missing(name, *args, &block)
        return super if name == :to_ary
        tags = CONCERN_MAP.fetch(name, [name])
        existing = @tags_store[@attribute_name]
        tags.each { |t| existing << t unless existing.include?(t) }
        self
      end

      def respond_to_missing?(name, include_private = false)
        name != :to_ary || super
      end
    end
  end
end
