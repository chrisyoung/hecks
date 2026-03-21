# ActiveHecks
#
# Adds ActiveModel compatibility to generated domain objects so they work
# seamlessly with Rails form helpers, URL helpers, error display, and
# serialization. Extends aggregates with identity-based persistence semantics
# and value objects with no-identity semantics.
#
# This is an optional integration layer -- only needed when using Hecks
# domain gems inside a Rails application.
#
#   require "active_hecks"
#   ActiveHecks.activate(PizzasDomain)
#
#   # Now works in Rails views:
#   form_with(model: pizza) { |f| f.text_field :name }
#
require "active_model"

module ActiveHecks
  # Activate ActiveModel compatibility on all aggregates and value objects
  # in a generated domain module.
  #
  #   ActiveHecks.activate(PizzasDomain)
  #
  # After activation, domain objects work with Rails form helpers,
  # URL helpers, error display, and serialization.
  def self.activate(domain_module)
    domain_module.constants.each do |const_name|
      const = domain_module.const_get(const_name)

      if const.is_a?(Class)
        # Direct aggregate (single context)
        extend_aggregate(const)
        extend_nested_value_objects(const)
      elsif const.is_a?(Module) && !%i[Ports Adapters].include?(const_name)
        # Context module — recurse into it
        const.constants.each do |agg_name|
          agg_class = const.const_get(agg_name)
          next unless agg_class.is_a?(Class)
          extend_aggregate(agg_class)
          extend_nested_value_objects(agg_class)
        end
      end
    end
  end

  def self.extend_nested_value_objects(klass)
    klass.constants.each do |nested_name|
      nested = klass.const_get(nested_name)
      next unless nested.is_a?(Class)
      extend_value_object(nested)
    end
  end

  def self.extend_aggregate(klass)
    klass.include(DomainModelCompat)
    klass.include(AggregateCompat)
    override_model_name(klass)
  end

  def self.extend_value_object(klass)
    klass.include(DomainModelCompat)
    klass.include(ValueObjectCompat)
    override_model_name(klass)
  end

  # Strip the domain module prefix so Pizza is "Pizza", not "PizzasDomain::Pizza"
  def self.override_model_name(klass)
    short_name = klass.name.split("::").last
    klass.define_singleton_method(:model_name) do
      @_model_name ||= ActiveModel::Name.new(self, nil, short_name)
    end
  end

  # Shared compatibility for all domain objects
  module DomainModelCompat
    def self.included(base)
      base.extend(ActiveModel::Naming) unless base.respond_to?(:model_name)
      base.include(ActiveModel::Conversion)
    end

    def to_model
      self
    end

    def errors
      @_errors ||= ActiveModel::Errors.new(self)
    end

    def attributes
      hash = {}
      self.class.instance_method(:initialize).parameters.each do |_, name|
        next unless name
        hash[name.to_s] = send(name) if respond_to?(name)
      end
      hash
    end

    def serializable_hash(options = nil)
      attributes
    end

    def read_attribute_for_serialization(attr)
      send(attr)
    end
  end

  # Aggregate-specific (has identity)
  module AggregateCompat
    def to_param
      id
    end

    def to_key
      persisted? ? [id] : nil
    end

    def persisted?
      !id.nil?
    end

    def new_record?
      !persisted?
    end

    def destroyed?
      false
    end
  end

  # Value object-specific (no identity)
  module ValueObjectCompat
    def to_param
      nil
    end

    def to_key
      nil
    end

    def persisted?
      false
    end

    def new_record?
      true
    end

    def destroyed?
      false
    end
  end
end
