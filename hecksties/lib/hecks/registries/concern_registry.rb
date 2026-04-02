# Hecks::ConcernRegistryMethods
#
# Module-level methods for registering and retrieving custom concerns.
# Extended into the Hecks module so concerns are available globally.
#
#   Hecks.concern(:hipaa) { description "HIPAA"; requires_extension :pii }
#   Hecks.custom_concerns         # => ConcernRegistry
#   Hecks.find_concern(:hipaa)    # => Concern
#
module Hecks
  module ConcernRegistryMethods
    # Access the global custom concern registry.
    #
    # @return [CustomConcerns::ConcernRegistry]
    def custom_concerns
      @custom_concern_registry ||= CustomConcerns::ConcernRegistry.new
    end

    # Define and register a custom concern using the DSL block.
    #
    # @param name [Symbol] concern identifier
    # @yield DSL block evaluated in ConcernBuilder context
    # @return [CustomConcerns::Concern] the registered concern
    def concern(name, &block)
      builder = CustomConcerns::ConcernBuilder.new(name)
      builder.instance_eval(&block) if block
      concern = builder.build
      custom_concerns.register(concern)
      concern
    end

    # Look up a custom concern by name.
    #
    # @param name [Symbol] the concern name
    # @return [CustomConcerns::Concern, nil]
    def find_concern(name)
      custom_concerns.find(name)
    end
  end
end
