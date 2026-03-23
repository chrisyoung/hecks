require 'hecks/query'

module PizzasDomain
  class Pizza
    module Queries
      class Classics
        include Hecks::Query

        def call
          true
        end
      end
    end
  end
end
