# Hecks::Services::Persistence::RepositoryMethods
#
# Opt-in mixin that provides persistence methods on aggregate classes.
# Adds ActiveRecord-style class and instance methods for CRUD and queries.
# All repo references are closure-captured so multiple Applications
# booting the same domain get isolated bindings.
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
    module Persistence
      module RepositoryMethods
      def self.bind(klass, repo)
        klass.instance_variable_set(:@__hecks_repo__, repo)
        bind_class_methods(klass, repo)
        bind_instance_methods(klass, repo)
      end

      def self.bind_class_methods(klass, repo)
        klass.define_singleton_method(:find) { |id| repo.find(id) }
        klass.define_singleton_method(:all) { repo.all }
        klass.define_singleton_method(:count) { repo.count }
        klass.define_singleton_method(:delete) { |id| repo.delete(id) }
        klass.define_singleton_method(:first) { all.first }
        klass.define_singleton_method(:last) { all.last }

        klass.define_singleton_method(:create) do |**attrs|
          constructor_attrs = {}
          instance_method(:initialize).parameters
            .select { |type, _| type == :key || type == :keyreq }
            .map { |_, name| name }
            .reject { |n| [:id].include?(n) }
            .each { |param| constructor_attrs[param] = attrs.key?(param) ? attrs[param] : nil }
          aggregate = new(**constructor_attrs)
          aggregate.stamp_created! if aggregate.respond_to?(:stamp_created!)
          repo.save(aggregate)
          aggregate
        end
      end

      def self.bind_instance_methods(klass, repo)
        klass.define_method(:destroyed?) { !!@__destroyed__ }

        klass.define_method(:save) do
          return self if destroyed?
          repo.save(self)
          self
        end

        klass.define_method(:destroy) do
          repo.delete(id)
          @__destroyed__ = true
          self
        end

        klass.define_method(:update) do |**new_attrs|
          return self if destroyed?
          constructor_attrs = { id: id }
          self.class.instance_method(:initialize).parameters.each do |_, param_name|
            next unless param_name
            next if [:id].include?(param_name)
            if respond_to?(param_name)
              constructor_attrs[param_name] = new_attrs.key?(param_name) ? new_attrs[param_name] : send(param_name)
            end
          end
          updated = self.class.new(**constructor_attrs)
          updated.instance_variable_set(:@created_at, created_at) if respond_to?(:created_at)
          updated.stamp_updated! if updated.respond_to?(:stamp_updated!)
          repo.save(updated)
          updated
        end
      end

      private_class_method :bind_class_methods, :bind_instance_methods
      end
    end
  end
end
