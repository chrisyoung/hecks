# Hecks::Session::SmalltalkFeatures
#
# Exposes metadata about Smalltalk-inspired features for README generation.
# Each feature has a name, description, and example. The ReadmeGenerator
# introspects this to build the "Hecks Loves Smalltalk" section.
#
#   Hecks::Session::SmalltalkFeatures.all
#   # => [{ name: "Sketch & Play", ... }, ...]
#
module Hecks
  class Session
    module SmalltalkFeatures
      FEATURES = [
        {
          name: "Sketch & Play",
          description: "Two modes: sketch your domain, then play with it live",
          example: <<~EXAMPLE.strip
            hecks(pizzas sketch)> aggregate "Pizza"
            hecks(pizzas sketch)> Pizza.attr :name, String
            hecks(pizzas sketch)> Pizza.command("Create") { attribute :name, String }
            hecks(pizzas sketch)> play!
            hecks(pizzas play)> Pizza.create(name: "Margherita")
          EXAMPLE
        },
        {
          name: "Named Constants",
          description: "aggregate('Cat') gives you Cat, not a temporary variable",
          example: <<~EXAMPLE.strip
            hecks(scratch sketch)> aggregate "Cat"
            => #<Cat (0 attributes, 0 commands)>
            hecks(scratch sketch)> Cat.attr :name, String
            hecks(scratch sketch)> Cat.command("Adopt") { attribute :name, String }
          EXAMPLE
        },
        {
          name: "System Browser",
          description: "Browse all domain elements in a tree",
          example: <<~EXAMPLE.strip
            hecks(pizzas sketch)> browse
            Pizzas Domain
              \u251c\u2500\u2500 Pizza
              \u2502   \u251c\u2500\u2500 attributes: name (String), style (String)
              \u2502   \u2514\u2500\u2500 commands: CreatePizza
              \u2514\u2500\u2500 Order
                  \u251c\u2500\u2500 attributes: quantity (Integer)
                  \u2514\u2500\u2500 commands: PlaceOrder
          EXAMPLE
        },
        {
          name: "Message Not Understood",
          description: "Unknown methods suggest creating commands",
          example: <<~EXAMPLE.strip
            hecks(scratch sketch)> Cat.feed
            NoMethodError: Cat doesn't understand 'feed'.
              Create it with: Cat.command("Feed") { attribute :name, String }
          EXAMPLE
        },
      ].freeze

      def self.all
        FEATURES
      end
    end
  end
end
