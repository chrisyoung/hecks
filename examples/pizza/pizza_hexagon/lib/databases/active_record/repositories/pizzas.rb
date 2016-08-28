module Databases
  class ActiveRecord
    module Domain
      module Pizzas
        class Repository < ::ActiveRecord::Base
          self.table_name = "pizzas"
          serialize :toppings, JSON

          def self.create(args)
            super(args).id
          end

          def self.query(args={})
            where(id: args[:id]).limit(1).first
          end
        end
      end
    end
  end
end
