module Hecks
  module ValidationRules
    module Naming

    # Hecks::ValidationRules::Naming::AttributeNaming
    #
    # Warns about attribute names that leak implementation or carry redundant
    # prefixes. Catches three patterns:
    #
    # 1. Suffixes like +_data+ or +_info+ (e.g. +order_data+) -- vague,
    #    prefer the domain concept itself
    # 2. Redundant aggregate-name prefixes (e.g. +pizza_name+ on Pizza) --
    #    the aggregate context already provides the namespace
    # 3. Hungarian-style type prefixes (e.g. +str_name+, +int_count+) --
    #    types are declared explicitly in the DSL
    #
    # This is a warning-only rule: it does not block compilation.
    #
    # == Usage
    #
    #   domain = Hecks.domain("Pizzas") do
    #     aggregate("Pizza") do
    #       attribute :pizza_name, String
    #       attribute :toppings_data, String
    #       command("CreatePizza") { attribute :name, String }
    #     end
    #   end
    #
    #   rule = AttributeNaming.new(domain)
    #   rule.warnings
    #   # => ["Attribute 'pizza_name' on Pizza has redundant prefix 'pizza_' ..."]
    #
    class AttributeNaming < BaseRule
      VAGUE_SUFFIXES = %w[_data _info _details _stuff _object _record].freeze
      TYPE_PREFIXES  = %w[str_ int_ bool_ arr_ lst_ hash_ obj_ num_ flt_].freeze

      # No errors -- this rule only produces warnings.
      #
      # @return [Array] always empty
      def errors
        []
      end

      # Returns warnings for attributes with vague suffixes, redundant
      # aggregate prefixes, or Hungarian-style type prefixes.
      #
      # @return [Array<ValidationMessage>] warning messages
      def warnings
        result = []
        @domain.aggregates.each do |agg|
          check_attrs(agg, agg.name, agg.attributes, result)
          agg.value_objects.each { |vo| check_attrs(agg, vo.name, vo.attributes, result) }
          agg.entities.each      { |ent| check_attrs(agg, ent.name, ent.attributes, result) }
        end
        result
      end

      private

      # Checks a set of attributes for naming smells.
      #
      # @param agg [Aggregate] the owning aggregate (for context)
      # @param owner_name [String] the immediate owner name (aggregate/VO/entity)
      # @param attributes [Array<Attribute>] the attributes to check
      # @param result [Array<ValidationMessage>] collects warnings
      def check_attrs(agg, owner_name, attributes, result)
        prefix = "#{owner_name.gsub(/([a-z])([A-Z])/, '\1_\2').downcase}_"
        attributes.each do |attr|
          name = attr.name.to_s
          result.concat(check_vague_suffix(name, owner_name))
          result.concat(check_redundant_prefix(name, owner_name, prefix))
          result.concat(check_type_prefix(name, owner_name))
        end
      end

      # @return [Array<ValidationMessage>] warning if name ends with a vague suffix
      def check_vague_suffix(name, owner)
        VAGUE_SUFFIXES.each do |suffix|
          next unless name.end_with?(suffix)
          clean = name.chomp(suffix)
          return [error(
            "Attribute '#{name}' on #{owner} has vague suffix '#{suffix}'",
            hint: "Rename to '#{clean}' or a more specific domain term"
          )]
        end
        []
      end

      # @return [Array<ValidationMessage>] warning if name starts with aggregate prefix
      def check_redundant_prefix(name, owner, prefix)
        return [] unless name.start_with?(prefix) && name.length > prefix.length
        clean = name.sub(/\A#{Regexp.escape(prefix)}/, "")
        [error(
          "Attribute '#{name}' on #{owner} has redundant prefix '#{prefix}'",
          hint: "Rename to '#{clean}' -- the #{owner} context already provides the namespace"
        )]
      end

      # @return [Array<ValidationMessage>] warning if name starts with a type prefix
      def check_type_prefix(name, owner)
        TYPE_PREFIXES.each do |tp|
          next unless name.start_with?(tp) && name.length > tp.length
          clean = name.sub(/\A#{Regexp.escape(tp)}/, "")
          return [error(
            "Attribute '#{name}' on #{owner} has Hungarian-style type prefix '#{tp}'",
            hint: "Rename to '#{clean}' -- types are declared explicitly in the DSL"
          )]
        end
        []
      end
    end
    Hecks.register_validation_rule(AttributeNaming)
    end
  end
end
