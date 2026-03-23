# Hecks::Services::Persistence::RepositoryMethods
#
# Adds CRUD persistence methods to aggregate classes. Bound automatically
# by Persistence.bind during application setup. Uses hecks_attributes
# metadata for introspection, falling back to constructor parameters.
#
#   Pizza.find(id) / Pizza.all / Pizza.count
#   Pizza.create(name: "Margherita")
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
          RepositoryMethods.attr_names(self).each { |n| constructor_attrs[n] = attrs.key?(n) ? attrs[n] : nil }
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
          RepositoryMethods.attr_names(self.class).each do |name|
            constructor_attrs[name] = new_attrs.key?(name) ? new_attrs[name] : send(name)
          end
          updated = self.class.new(**constructor_attrs)
          updated.instance_variable_set(:@created_at, created_at) if respond_to?(:created_at)
          updated.stamp_updated! if updated.respond_to?(:stamp_updated!)
          repo.save(updated)
          updated
        end
      end

      private_class_method :bind_class_methods, :bind_instance_methods

      def self.attr_names(klass)
        if klass.respond_to?(:hecks_attributes)
          klass.hecks_attributes.map { |a| a[:name] }
        else
          klass.instance_method(:initialize).parameters
            .select { |type, _| type == :key || type == :keyreq }
            .map { |_, name| name }
            .reject { |n| n == :id }
        end
      end
      end
    end
  end
end
