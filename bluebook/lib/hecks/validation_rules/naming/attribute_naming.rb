module Hecks
  module ValidationRules
    module Naming

    # Hecks::ValidationRules::Naming::AttributeNaming
    #
    # Advisory warning for attribute names that use suspicious prefixes or
    # suffixes. Catches common anti-patterns like Hungarian notation
    # (str_name), redundant type suffixes (name_string), and boolean
    # prefixes (is_active) that weaken the ubiquitous language.
    #
    # Part of the ValidationRules::Naming group -- run by +Hecks.validate+.
    #
    # Example trigger:
    #   attribute :str_name, String
    #   attribute :is_active, Boolean
    #
    # Would warn about prefix/suffix conventions.
    class AttributeNaming < BaseRule
      SUSPECT_PREFIXES = %w[str int bool num arr lst tmp my the].freeze
      SUSPECT_SUFFIXES = %w[_string _integer _int _float _bool _boolean _array _list _hash].freeze
      BOOLEAN_PREFIXES = %w[is_ has_ was_ did_ should_ can_ will_].freeze

      # Returns no errors. This rule only produces warnings.
      #
      # @return [Array<String>] always empty
      def errors
        []
      end

      # Returns a warning for each attribute with a suspect prefix, type
      # suffix, or boolean naming convention issue.
      #
      # @return [Array<ValidationMessage>] warning messages
      def warnings
        result = []
        @domain.aggregates.each do |agg|
          agg.attributes.each do |attr|
            result.concat(check_attribute(agg, attr))
          end
        end
        result
      end

      private

      def check_attribute(agg, attr)
        name = attr.name.to_s
        warnings = []

        SUSPECT_PREFIXES.each do |prefix|
          if name.start_with?("#{prefix}_")
            warnings << error("#{agg.name}.#{name} has Hungarian-notation prefix '#{prefix}_'",
              hint: "Remove the type prefix: '#{name.sub("#{prefix}_", "")}'")
          end
        end

        SUSPECT_SUFFIXES.each do |suffix|
          if name.end_with?(suffix)
            warnings << error("#{agg.name}.#{name} has redundant type suffix '#{suffix}'",
              hint: "Remove the suffix: '#{name.chomp(suffix)}'")
          end
        end

        BOOLEAN_PREFIXES.each do |prefix|
          if name.start_with?(prefix) && boolean_type?(attr)
            short = name.sub(prefix, "")
            warnings << error("#{agg.name}.#{name} uses '#{prefix}' prefix on a Boolean",
              hint: "Use '#{short}' or '#{short}?' style instead")
          end
        end

        warnings
      end

      def boolean_type?(attr)
        t = attr.type.to_s.downcase
        t == "boolean" || t == "trueclass" || t == "falseclass"
      end
    end
    Hecks.register_validation_rule(AttributeNaming)
    end
  end
end
