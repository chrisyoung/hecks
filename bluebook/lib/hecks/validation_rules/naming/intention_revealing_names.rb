module Hecks
  module ValidationRules
    module Naming

    # Hecks::ValidationRules::Naming::IntentionRevealingNames
    #
    # Warns when aggregate, value object, or entity names use generic terms
    # that hide domain intent. Names like "Data", "Info", "Manager", and
    # "Handler" are code smells in DDD -- they reveal implementation rather
    # than domain meaning.
    #
    # This is a warning-only rule: it does not block compilation.
    #
    # == Usage
    #
    #   domain = Hecks.domain("Pizzas") do
    #     aggregate("OrderManager") do
    #       attribute :name, String
    #       command("CreateOrderManager") { attribute :name, String }
    #     end
    #   end
    #
    #   rule = IntentionRevealingNames.new(domain)
    #   rule.warnings
    #   # => ["Aggregate 'OrderManager' uses generic term 'Manager' ..."]
    #
    class IntentionRevealingNames < BaseRule
      GENERIC_TERMS = %w[
        Data Info Manager Handler Processor Helper Util Utils
        Service Object Base Item Record Entry Wrapper Container
      ].freeze

      GENERIC_PATTERN = /(?:^|(?<=[a-z]))(?:#{GENERIC_TERMS.join("|")})(?=[A-Z]|\z)/

      # No errors -- this rule only produces warnings.
      #
      # @return [Array] always empty
      def errors
        []
      end

      # Returns warnings for aggregates, value objects, and entities whose
      # names contain generic, non-intention-revealing terms.
      #
      # @return [Array<ValidationMessage>] warning messages
      def warnings
        result = []
        @domain.aggregates.each do |agg|
          result.concat(check_name("Aggregate", agg.name))
          agg.value_objects.each { |vo| result.concat(check_name("ValueObject", vo.name)) }
          agg.entities.each      { |ent| result.concat(check_name("Entity", ent.name)) }
        end
        result
      end

      private

      # Scans a PascalCase name for generic terms and returns a warning
      # for each match found.
      #
      # @param kind [String] human-readable label (e.g. "Aggregate")
      # @param name [String] the PascalCase name to check
      # @return [Array<ValidationMessage>] warnings for this name
      def check_name(kind, name)
        matches = name.scan(GENERIC_PATTERN)
        matches.map do |term|
          error(
            "#{kind} '#{name}' uses generic term '#{term}' -- prefer a domain-specific name",
            hint: "Replace '#{term}' with a term from your ubiquitous language"
          )
        end
      end
    end
    Hecks.register_validation_rule(IntentionRevealingNames)
    end
  end
end
