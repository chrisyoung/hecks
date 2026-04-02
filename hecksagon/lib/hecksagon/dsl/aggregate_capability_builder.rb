module Hecksagon
  module DSL

    # Hecksagon::DSL::AggregateCapabilityBuilder
    #
    # DSL builder for declaring attribute-level capabilities (tags) on an
    # aggregate. Bare attribute names resolve via +method_missing+ into
    # TagApplier instances that collect concern-based tags.
    #
    #   builder = AggregateCapabilityBuilder.new("Customer")
    #   builder.instance_eval do
    #     email.privacy
    #     ssn.privacy.searchable
    #   end
    #   builder.build  # => { "email" => [:pii, :encrypted, :masked], "ssn" => [..., :searchable] }
    #
    class AggregateCapabilityBuilder
      def initialize(aggregate_name)
        @aggregate_name = aggregate_name.to_s
        @attribute_tags = {}
      end

      # Returns self so `capability.email.privacy` works as a backward-compat
      # prefix. The `capability.` part is a no-op.
      #
      # @return [self]
      def capability
        self
      end

      # Catch bare attribute names and return a TagApplier for chaining.
      #
      # @param name [Symbol] the attribute name
      # @return [TagApplier] a chainable tag applier for the attribute
      def method_missing(name, *args, &block)
        return super if name == :to_ary
        @attribute_tags[name.to_s] ||= []
        TagApplier.new(name.to_s, @attribute_tags)
      end

      def respond_to_missing?(name, include_private = false)
        name != :to_ary || super
      end

      # Build the final hash of attribute name to tag arrays.
      #
      # @return [Hash{String => Array<Symbol>}]
      def build
        @attribute_tags
      end
    end
  end
end
