module Hecks
  module ValidationRules
    module Naming

    # Hecks::ValidationRules::Naming::EventNaming
    #
    # Warns when domain event names do not follow past-tense convention.
    # In DDD, events describe something that already happened, so names
    # like "CreatedPizza" and "ApprovedOrder" are correct, while
    # "CreatePizza" or "ApprovingOrder" are not.
    #
    # Detection: checks that the first PascalCase word ends in "ed", "en",
    # "nt" (sent), "un" (begun), or "id" (paid). This catches the vast
    # majority of English past-tense verb forms.
    #
    # This is a warning-only rule: it does not block compilation.
    #
    # == Usage
    #
    #   domain = Hecks.domain("Pizzas") do
    #     aggregate("Pizza") do
    #       attribute :name, String
    #       command("CreatePizza") { attribute :name, String }
    #       event("BakePizza")
    #     end
    #   end
    #
    #   rule = EventNaming.new(domain)
    #   rule.warnings
    #   # => ["Event 'BakePizza' in Pizza does not appear to be past tense ..."]
    #
    class EventNaming < BaseRule
      PAST_TENSE_SUFFIXES = /(?:ed|en|nt|un|id)\z/i

      # No errors -- this rule only produces warnings.
      #
      # @return [Array] always empty
      def errors
        []
      end

      # Returns warnings for events whose first word does not look like
      # past tense.
      #
      # @return [Array<ValidationMessage>] warning messages
      def warnings
        result = []
        @domain.aggregates.each do |agg|
          agg.events.each do |evt|
            first_word = evt.name.split(/(?=[A-Z])/).first
            next if first_word.match?(PAST_TENSE_SUFFIXES)

            result << error(
              "Event '#{evt.name}' in #{agg.name} does not appear to be past tense",
              hint: "Rename to past tense, e.g. '#{suggest_past_tense(first_word, evt.name)}'"
            )
          end
        end
        result
      end

      private

      # Suggests a past-tense version of the event name by appending "ed"
      # to the first word (or "d" if it ends with "e").
      #
      # @param first_word [String] the verb portion of the event name
      # @param full_name [String] the full PascalCase event name
      # @return [String] a suggested past-tense event name
      def suggest_past_tense(first_word, full_name)
        suffix = full_name.sub(/\A#{Regexp.escape(first_word)}/, "")
        past = first_word.end_with?("e") ? "#{first_word}d" : "#{first_word}ed"
        "#{past}#{suffix}"
      end
    end
    Hecks.register_validation_rule(EventNaming)
    end
  end
end
