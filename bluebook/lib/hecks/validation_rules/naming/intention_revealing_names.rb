module Hecks
  module ValidationRules
    module Naming

    # Hecks::ValidationRules::Naming::IntentionRevealingNames
    #
    # Advisory warning for aggregate or attribute names that are too generic
    # to convey domain meaning. Names like "Data", "Info", "Item", "Thing",
    # "Record", "Object" hide intent and weaken the ubiquitous language.
    #
    # Part of the ValidationRules::Naming group -- run by +Hecks.validate+.
    #
    # Example trigger:
    #   aggregate "DataItem" do
    #     attribute :info, String
    #   end
    #
    # Would warn: "DataItem uses generic name -- consider a more intention-revealing name"
    class IntentionRevealingNames < BaseRule
      GENERIC_WORDS = %w[
        data info item thing record object entry row
        stuff blob payload container holder wrapper
        manager handler processor helper util
      ].freeze

      # Returns no errors. This rule only produces warnings.
      #
      # @return [Array<String>] always empty
      def errors
        []
      end

      # Returns a warning for aggregates or attributes whose names contain
      # generic words that obscure domain intent.
      #
      # @return [Array<ValidationMessage>] warning messages
      def warnings
        result = []
        @domain.aggregates.each do |agg|
          result.concat(check_aggregate_name(agg))
          result.concat(check_attribute_names(agg))
        end
        result
      end

      private

      def check_aggregate_name(agg)
        words = split_pascal(agg.name).map(&:downcase)
        generic = words & GENERIC_WORDS
        return [] if generic.empty?

        [error("#{agg.name} uses generic name ('#{generic.join("', '")}') -- consider a more intention-revealing name",
          hint: "Rename to describe what this aggregate represents in the domain")]
      end

      def check_attribute_names(agg)
        agg.attributes.flat_map do |attr|
          name = attr.name.to_s
          if GENERIC_WORDS.include?(name.downcase)
            [error("#{agg.name}.#{name} is a generic attribute name",
              hint: "Rename to describe the attribute's purpose (e.g., 'data' -> 'payload_json')")]
          else
            []
          end
        end
      end

      def split_pascal(name)
        name.scan(/[A-Z][a-z]*/)
      end
    end
    Hecks.register_validation_rule(IntentionRevealingNames)
    end
  end
end
