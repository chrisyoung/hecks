require_relative "aggregate_handle/presenter"
require_relative "aggregate_handle/behavior_methods"
require_relative "aggregate_handle/constraint_methods"
require_relative "aggregate_handle/query_methods"
require_relative "aggregate_handle/implicit_syntax"
require_relative "command_handle"

module Hecks
  class Workshop
    # Hecks::Workshop::AggregateHandle
    #
    # Interactive handle for incrementally building a single aggregate in the
    # REPL. Wraps an AggregateBuilder and provides add/remove methods that
    # print feedback as you go. Supports one-line dot syntax via method_missing.
    #
    #   Post.title String         # implicit attribute
    #   Post.create               # implicit command, returns CommandHandle
    #   Post.create.title String  # add attribute to command
    #   Post.lifecycle :status, default: "draft"
    #   Post.transition "PublishPost" => "published"
    #
    class AggregateHandle
      include HecksTemplating::NamingHelpers
      include Presenter
      include BehaviorMethods
      include ConstraintMethods
      include QueryMethods
      include ImplicitSyntax

    attr_reader :name

    def initialize(name, builder, domain_module:, workshop: nil)
      @name = name
      @builder = builder
      @domain_module = domain_module
      @workshop = workshop
      @command_handles = {}
    end

    def attr(name, type = String, **options)
      check_duplicate_attr!(name)
      @builder.attribute(name, type, **options)
      if type.is_a?(Hash) && type[:reference]
        puts "#{name} reference added to #{@name} -> #{type[:reference]}"
        check_bidirectional(type[:reference])
      else
        puts "#{name} attribute added to #{@name}"
      end
      self
    end

    def remove(name)
      attrs = @builder.attributes
      removed = attrs.reject! { |a| a.name == name.to_sym }
      if removed
        puts "#{name} attribute removed from #{@name}"
      else
        puts "no attribute #{name} on #{@name}"
      end
      self
    end

    def value_object(name, &block)
      name = normalize_name(name)
      @builder.value_object(name, &block)
      puts "#{name} value object created on #{@name}"
      self
    end

    def entity(name, &block)
      name = normalize_name(name)
      @builder.entity(name, &block)
      puts "#{name} entity created on #{@name}"
      self
    end

    def verb(word)
      @workshop&.add_verb(word)
      puts "#{word} verb registered"
      self
    end

    def attributes
      @builder.attributes.map(&:name)
    end

    def commands
      @builder.commands.map(&:name)
    end

    def value_objects
      @builder.value_objects.map { |vo| vo.respond_to?(:name) ? vo.name : vo.build.name }
    end

    def entities
      @builder.entities.map { |ent| ent.respond_to?(:name) ? ent.name : ent.build.name }
    end

    def list_of(type) = { list: type }
    def reference_to(type) = { reference: type }

    private

    def check_duplicate_attr!(name)
      if @builder.attributes.any? { |a| a.name == name.to_sym }
        raise ArgumentError, "#{@name} already has attribute :#{name}"
      end
    end

    def normalize_name(name)
      domain_constant_name(name)
    end

    def infer_command_name(snake)
      parts = snake.to_s.split("_")
      if parts.size == 1
        parts.first.capitalize + @name
      else
        parts.map(&:capitalize).join
      end
    end

    def check_bidirectional(target_name)
      return unless @workshop
      domain = @workshop.to_domain
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
