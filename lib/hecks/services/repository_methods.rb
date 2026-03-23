# Hecks::Services::RepositoryMethods
#
# Opt-in mixin that provides persistence methods on aggregate classes.
# Adds ActiveRecord-style class and instance methods for CRUD and queries.
# Enable in your project — not included by default.
#
#   # Plain Ruby:
#   app = Hecks::Services::Application.new(domain)
#   Hecks::Services::RepositoryMethods.bind(PizzasDomain::Pizza, app["Pizza"])
#
#   # Rails initializer:
#   Hecks::Services::RepositoryMethods.bind(Pizza, pizza_repo)
#
#   # Then use:
#   Pizza.find(id)
#   Pizza.create(name: "Margherita")
#   Pizza.all / Pizza.count / Pizza.first / Pizza.last
#   Pizza.where(style: "Classic").order(:name).limit(5)
#   pizza.save / pizza.update(name: "New") / pizza.destroy
#
module Hecks
  module Services
    module RepositoryMethods
      def self.bind(klass, repo)
        klass.instance_variable_set(:@__hecks_repo__, repo)
        klass.extend(ClassMethods)
        klass.include(InstanceMethods)
      end

      module ClassMethods
        def find(id)
          @__hecks_repo__.find(id)
        end

        def all
          @__hecks_repo__.all
        end

        def count
          @__hecks_repo__.count
        end

        def delete(id)
          @__hecks_repo__.delete(id)
        end

        def first
          all.first
        end

        def last
          all.last
        end

        def create(**attrs)
          now = Time.now
          constructor_attrs = { created_at: now, updated_at: now }
          new_instance_params.each do |param|
            constructor_attrs[param] = attrs.key?(param) ? attrs[param] : nil
          end
          aggregate = new(**constructor_attrs)
          @__hecks_repo__.save(aggregate)
          aggregate
        end

        private

        def new_instance_params
          instance_method(:initialize).parameters
            .select { |type, _| type == :key || type == :keyreq }
            .map { |_, name| name }
            .reject { |n| [:id, :created_at, :updated_at].include?(n) }
        end
      end

      module InstanceMethods
        def save
          self.class.instance_variable_get(:@__hecks_repo__).save(self)
          self
        end

        def destroy
          self.class.instance_variable_get(:@__hecks_repo__).delete(id)
          self
        end

        def update(**new_attrs)
          repo = self.class.instance_variable_get(:@__hecks_repo__)
          constructor_attrs = {
            id: id,
            created_at: (created_at if respond_to?(:created_at)),
            updated_at: Time.now
          }
          self.class.instance_method(:initialize).parameters.each do |_, param_name|
            next unless param_name
            next if [:id, :created_at, :updated_at].include?(param_name)
            if respond_to?(param_name)
              constructor_attrs[param_name] = new_attrs.key?(param_name) ? new_attrs[param_name] : send(param_name)
            end
          end
          updated = self.class.new(**constructor_attrs)
          repo.save(updated)
          updated
        end
      end
    end
  end
end
