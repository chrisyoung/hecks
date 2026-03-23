# Hecks::Services::AdHocQueries
#
# Opt-in mixin that provides ActiveRecord-style query methods (where,
# find_by, first, last) on aggregate classes. Enable in your project:
#
#   # Plain Ruby:
#   app = Hecks::Services::Application.new(domain)
#   Hecks::Services::AdHocQueries.bind(PizzasDomain::Pizza, app["Pizza"])
#
#   # Rails initializer:
#   Hecks::Services::AdHocQueries.bind(Pizza, pizza_repo)
#
#   # Then use:
#   Pizza.where(style: "Classic").order(:name).limit(5)
#   Pizza.find_by(name: "Margherita")
#
module Hecks
  module Services
    module AdHocQueries
      def self.bind(klass, repo)
        klass.instance_variable_set(:@__hecks_repo__, repo)
        klass.extend(self)
      end

      def where(**conditions)
        QueryBuilder.new(@__hecks_repo__).where(**conditions)
      end

      def find_by(**conditions)
        QueryBuilder.new(@__hecks_repo__).find_by(**conditions)
      end

      def first
        all.first
      end

      def last
        all.last
      end
    end
  end
end
