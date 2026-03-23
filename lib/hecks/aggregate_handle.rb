# Hecks::AggregateHandle
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
  class AggregateHandle
    include Presenter

    attr_reader :name

    def initialize(name, builder, domain_module:, session: nil)
      @name = name
      @builder = builder
      @domain_module = domain_module
      @session = session
    end

    def add_attribute(name, type, **options)
      @builder.attribute(name, type, **options)
      puts "  + attribute :#{name}, #{type_label(type)}"

      if type.is_a?(Hash) && type[:reference]
        check_bidirectional(type[:reference])
      end

      self
    end

    def remove_attribute(name)
      attrs = @builder.attributes
      removed = attrs.reject! { |a| a.name == name.to_sym }
      if removed
        puts "  - attribute :#{name}"
      else
        puts "  No attribute :#{name}"
      end
      self
    end

    def add_value_object(name, &block)
      @builder.value_object(name, &block)
      puts "  + value_object #{name}"
      self
    end

    def add_command(name, &block)
      @builder.command(name, &block)
      cmd = @builder.commands.last
      puts "  + command #{name} -> #{cmd.inferred_event_name}"
      self
    end

    def add_validation(field, rules)
      @builder.validation(field, rules)
      puts "  + validation :#{field}, #{rules.keys.join(', ')}"
      self
    end

    def add_invariant(message, &block)
      @builder.invariant(message, &block)
      puts "  + invariant \"#{message}\""
      self
    end

    def add_policy(name, &block)
      @builder.policy(name, &block)
      pol = @builder.policies.last
      puts "  + policy #{name} (on #{pol.event_name} -> #{pol.trigger_command})"
      self
    end

    def attributes
      @builder.attributes.map(&:name)
    end

    def commands
      @builder.commands.map(&:name)
    end

    def value_objects
      @builder.value_objects.map { |vo| vo.is_a?(DomainModel::Structure::ValueObject) ? vo.name : vo.build.name }
    end

    # Show the generated code for this aggregate
    def preview
      agg = @builder.build
      domain_module = @domain_module || "Domain"
      gen = Generators::Domain::AggregateGenerator.new(agg, domain_module: domain_module)
      puts gen.generate
      nil
    end

    # DSL helpers for use in blocks
    def list_of(type)
      { list: type }
    end

    def reference_to(type)
      { reference: type }
    end

    private

    def check_bidirectional(target_name)
      return unless @session

      domain = @session.to_domain
      domain.contexts.each do |ctx|
        target_agg = ctx.aggregates.find { |a| a.name == target_name.to_s }
        next unless target_agg

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
