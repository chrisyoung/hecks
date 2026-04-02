# = Hecks::TestHelper::PropertyTesting::TypeGenerators
#
# Per-type random value generators for property-based testing. Each Hecks
# attribute type (String, Integer, Float, Date, etc.) has a corresponding
# generator that produces random valid values. Handles list_of and
# reference_to attributes. Seed is configurable for reproducibility.
#
#   gen = TypeGenerators.new(seed: 42)
#   gen.generate(String)              # => "prop_kxqz"
#   gen.generate(Integer)             # => 847
#   gen.generate_for_attribute(attr)  # handles list/reference types
#
module Hecks
  module TestHelper
    module PropertyTesting
      class TypeGenerators
        attr_reader :rng

        # @param seed [Integer, nil] random seed for reproducibility
        def initialize(seed: nil)
          @seed = seed || Random.new_seed
          @rng = Random.new(@seed)
        end

        # @return [Integer] the seed used by this generator
        def seed
          @seed
        end

        # Generate a random value for a given type class.
        #
        # @param type [Class, String] the attribute type
        # @return [Object] a random value of the appropriate type
        def generate(type)
          type_key = type.is_a?(Class) ? type.name : type.to_s

          case type_key
          when "String"   then generate_string
          when "Integer"  then generate_integer
          when "Float"    then generate_float
          when "Date"     then generate_date
          when "DateTime" then generate_datetime
          when "JSON"     then generate_json
          else
            type.is_a?(String) ? generate_reference_id : generate_string
          end
        end

        # Generate a value appropriate for an Attribute IR node, handling
        # list_of and reference_to patterns.
        #
        # @param attribute [Hecks::DomainModel::Structure::Attribute] the attribute
        # @return [Object] a random valid value
        def generate_for_attribute(attribute)
          if attribute.list?
            generate_list(attribute.type)
          elsif attribute.enum
            attribute.enum.sample(random: @rng)
          else
            generate(attribute.type)
          end
        end

        private

        def generate_string
          len = @rng.rand(3..12)
          chars = ("a".."z").to_a
          "prop_" + Array.new(len) { chars[@rng.rand(chars.size)] }.join
        end

        def generate_integer
          @rng.rand(1..10_000)
        end

        def generate_float
          (@rng.rand * 1000).round(2)
        end

        def generate_date
          days_offset = @rng.rand(-365..365)
          Date.today + days_offset
        end

        def generate_datetime
          days_offset = @rng.rand(-365..365)
          DateTime.now + days_offset
        end

        def generate_json
          keys = %w[alpha beta gamma delta]
          key = keys[@rng.rand(keys.size)]
          { key => @rng.rand(1..100) }
        end

        def generate_reference_id
          format(
            "%08x-%04x-%04x-%04x-%012x",
            @rng.rand(0xFFFFFFFF),
            @rng.rand(0xFFFF),
            @rng.rand(0xFFFF),
            @rng.rand(0xFFFF),
            @rng.rand(0xFFFFFFFFFFFF)
          )
        end

        def generate_list(element_type)
          count = @rng.rand(0..5)
          Array.new(count) { generate(element_type) }
        end
      end
    end
  end
end
