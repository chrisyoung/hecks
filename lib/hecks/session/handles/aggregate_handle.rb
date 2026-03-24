# Hecks::Session::AggregateHandle
#
# Interactive handle for incrementally building a single aggregate in the
# REPL. Wraps an AggregateBuilder and provides add/remove methods that
# print feedback as you go.
#
# Part of the Session layer -- returned by Session#aggregate to allow
# step-by-step aggregate construction without full DSL blocks.
#
#   session = Hecks.session("Pizzas")
#   pizza = session.aggregate("Pizza")
#   pizza.add_attribute(:name, String)
#   pizza.add_command("CreatePizza") { attribute :name, String }
#   pizza.add_validation(:name, presence: true)
#   pizza.describe   # prints a summary of the aggregate
#   pizza.preview    # prints generated Ruby code
#
require_relative "aggregate_handle/presenter"

module Hecks
  class Session
    class AggregateHandle
    include Presenter

    attr_reader :name

    def initialize(name, builder, domain_module:, session: nil)
      @name = name
      @builder = builder
      @domain_module = domain_module
      @session = session
    end

    def attr(name, type = String, **options)
      check_duplicate_attr!(name)
      @builder.attribute(name, type, **options)
      puts "  + attr :#{name}, #{type_label(type)}"

      if type.is_a?(Hash) && type[:reference]
        check_bidirectional(type[:reference])
      end

      self
    end



    def remove(name)
      attrs = @builder.attributes
      removed = attrs.reject! { |a| a.name == name.to_sym }
      if removed
        puts "  - attribute :#{name}"
      else
        puts "  No attribute :#{name}"
      end
      self
    end

    def value_object(name, &block)
      name = normalize_name(name)
      @builder.value_object(name, &block)
      puts "  + value_object #{name}"
      self
    end

    def command(name, &block)
      name = normalize_name(name)
      @builder.command(name, &block)
      cmd = @builder.commands.last
      puts "  + command #{name} -> #{cmd.inferred_event_name}"
      self
    end

    def validation(field, rules)
      @builder.validation(field, rules)
      puts "  + validation :#{field}, #{rules.keys.join(', ')}"
      self
    end

    def invariant(message, &block)
      @builder.invariant(message, &block)
      puts "  + invariant \"#{message}\""
      self
    end

    def policy(name, &block)
      name = normalize_name(name)
      @builder.policy(name, &block)
      pol = @builder.policies.last
      puts "  + policy #{name} (on #{pol.event_name} -> #{pol.trigger_command})"
      self
    end

    def verb(word)
      @session&.add_verb(word)
      puts "  + verb \"#{word}\""
      self
    end

    def query(name, &block)
      @builder.query(name, &block)
      puts "  + query #{name}"
      self
    end

    def scope(name, conditions = nil, &block)
      @builder.scope(name, conditions, &block)
      puts "  + scope #{name}"
      self
    end

    def on_event(event_name, async: false, &block)
      @builder.on_event(event_name, async: async, &block)
      puts "  + subscriber on #{event_name}"
      self
    end

    # Keep add_ prefixed names for backward compat (MCP, specs, examples)
    alias_method :attribute, :attr
    alias_method :add_attribute, :attr
    alias_method :attr_reader, :attr
    alias_method :remove_attribute, :remove
    alias_method :add_value_object, :value_object
    alias_method :add_command, :command
    alias_method :add_validation, :validation
    alias_method :add_invariant, :invariant
    alias_method :add_policy, :policy
    alias_method :add_verb, :verb
    alias_method :add_query, :query
    alias_method :add_scope, :scope

    def attributes
      @builder.attributes.map(&:name)
    end

    def commands
      @builder.commands.map(&:name)
    end

    def value_objects
      @builder.value_objects.map { |vo| vo.is_a?(DomainModel::Structure::ValueObject) ? vo.name : vo.build.name }
    end

    # DSL helpers for use in blocks
    def list_of(type)
      { list: type }
    end

    def reference_to(type)
      { reference: type }
    end

    private

    def check_duplicate_attr!(name)
      if @builder.attributes.any? { |a| a.name == name.to_sym }
        raise ArgumentError, "#{@name} already has attribute :#{name}"
      end
    end

    def normalize_name(name)
      Hecks::Utils.sanitize_constant(name)
    end

    def check_bidirectional(target_name)
      return unless @session

      domain = @session.to_domain
      target_agg = domain.aggregates.find { |a| a.name == target_name.to_s }
      return unless target_agg

      back_refs = target_agg.attributes.select(&:reference?).map { |a| a.type.to_s }
      if back_refs.include?(@name)
        puts "  !! WARNING: Bidirectional reference detected between #{@name} and #{target_name}."
        puts "     #{target_name} already references #{@name}. Aggregates should not reference"
        puts "     each other — one side should use events/policies instead."
      end
    end
  end
  end
end
