module Hecks
  module PropertyTesting

    # Hecks::PropertyTesting::TypeGenerator
    #
    # Generates random values for Hecks attribute types. Seeded randomness
    # ensures reproducible test runs. No external gems required.
    #
    #   gen = TypeGenerator.new(seed: 42)
    #   gen.string            # => "dxpk"
    #   gen.integer           # => 4821
    #   gen.for_type(String)  # => "mwqr"
    #
    class TypeGenerator
      CHARS = ("a".."z").to_a.freeze

      # @param seed [Integer] random seed for reproducibility
      def initialize(seed: Random.new_seed)
        @rng = Random.new(seed)
      end

      # Generate a value for a given Hecks type.
      #
      # @param type [Class, String] the attribute type
      # @return [Object] a random value of the appropriate type
      def for_type(type)
        case type.to_s
        when "String"   then string
        when "Integer"  then integer
        when "Float"    then float_val
        when "Boolean"  then boolean
        when "Date"     then date
        when "DateTime" then datetime
        else string
        end
      end

      # @return [String] random lowercase string of 4-12 characters
      def string
        len = @rng.rand(4..12)
        len.times.map { CHARS[@rng.rand(CHARS.size)] }.join
      end

      # @return [Integer] random integer between -10_000 and 10_000
      def integer
        @rng.rand(-10_000..10_000)
      end

      # @return [Float] random float between -1000.0 and 1000.0
      def float_val
        @rng.rand(-1000.0..1000.0)
      end

      # @return [Boolean] random true or false
      def boolean
        @rng.rand(2) == 1
      end

      # @return [Date] random date within last 5 years
      def date
        Date.today - @rng.rand(0..1825)
      end

      # @return [Time] random datetime within last 5 years
      def datetime
        Time.now - @rng.rand(0..157_680_000)
      end
    end
  end
end
