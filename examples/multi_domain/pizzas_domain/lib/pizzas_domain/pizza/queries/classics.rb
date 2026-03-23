require 'hecks/query'

module PizzasDomain
  class Pizza
    module Queries
      class Classics
        include Hecks::Query

        def call
          where(style: "Classic")
        end
      end
    end
  end
end
