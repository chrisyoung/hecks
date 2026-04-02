module Hecks
  module ValidationRules
    module Naming

    # Hecks::ValidationRules::Naming::EventNaming
    #
    # Advisory warning for domain events whose names are not in past tense.
    # DDD convention: events describe something that already happened, so they
    # should read as past-tense phrases (e.g., "CreatedPizza", "OrderPlaced").
    #
    # Part of the ValidationRules::Naming group -- run by +Hecks.validate+.
    #
    # Example trigger:
    #   event "CreatePizza"  # should be "CreatedPizza" or "PizzaCreated"
    #
    # Would warn: "Event CreatePizza should be past tense (e.g., CreatedPizza)"
    class EventNaming < BaseRule
      PAST_TENSE_SUFFIXES = %w[ed en].freeze

      # Returns no errors. This rule only produces warnings.
      #
      # @return [Array<String>] always empty
      def errors
        []
      end

      # Returns a warning for each event whose first word does not appear
      # to be past tense (ending in -ed or -en).
      #
      # @return [Array<ValidationMessage>] warning messages
      def warnings
        result = []
        @domain.aggregates.each do |agg|
          agg.events.each do |event|
            first_word = event.name.scan(/[A-Z][a-z]*/).first
            next unless first_word
            next if past_tense?(first_word)

            result << error("Event #{event.name} in #{agg.name} should be past tense",
              hint: "Rename to '#{suggest_past_tense(event.name)}' or similar past-tense form")
          end
        end
        result
      end

      private

      def past_tense?(word)
        lower = word.downcase
        PAST_TENSE_SUFFIXES.any? { |suffix| lower.end_with?(suffix) }
      end

      def suggest_past_tense(name)
        words = name.scan(/[A-Z][a-z]*/)
        return name if words.empty?
        first = words.first.downcase
        past = first.end_with?("e") ? "#{first}d" : "#{first}ed"
        words[0] = past.capitalize
        words.join
      end
    end
    Hecks.register_validation_rule(EventNaming)
    end
  end
end
