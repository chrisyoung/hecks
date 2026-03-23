# Hecks::DomainModel::Structure::Domain
#
# The root of the domain model intermediate representation. A domain contains
# aggregates directly.
#
#   domain = Domain.new(name: "Pizzas", aggregates: [pizza_agg, order_agg])
#   domain.aggregates  # => [pizza_agg, order_agg]
#
module Hecks
  module DomainModel
    module Structure
    class Domain
      attr_reader :name, :aggregates
      attr_accessor :source_path

      def initialize(name:, aggregates: [])
        @name = name
        @aggregates = aggregates
      end

      def module_name
        Hecks::Utils.sanitize_constant(name)
      end

      def gem_name
        Hecks::Utils.underscore(module_name) + "_domain"
      end
    end
    end
  end
end
