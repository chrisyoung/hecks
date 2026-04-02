# Hecks::Capabilities::Crud
#
# CRUD capability for the hecksagon. Generates Create, Read, Update, and
# Delete command stubs for each aggregate, skipping any command whose name
# the user already defined. Also binds repository methods (.find, .all,
# .create, .update, .delete, .count, .first, .last) via Persistence.
#
# Applied via:
#   runtime.capability(:crud)
#
# User-defined commands always take precedence -- if a "CreatePizza" already
# exists in the Bluebook, the capability will not generate a duplicate.
#
module Hecks
  module Capabilities
    module Crud
      extend HecksTemplating::NamingHelpers
      Structure = DomainModel::Structure
      Behavior  = DomainModel::Behavior

      CRUD_PREFIXES = %w[Create Read Update Delete].freeze

      # Apply CRUD to all aggregates in the runtime's domain.
      #
      # @param runtime [Hecks::Runtime] the booted runtime
      # @return [void]
      def self.apply(runtime)
        domain = runtime.domain
        mod_name = HecksTemplating::NamingHelpers.instance_method(:domain_module_name)
          .bind_call(self, domain.name)
        mod = Object.const_get(mod_name)

        domain.aggregates.each do |agg|
          new_commands, new_events = generate_stubs(agg)
          next if new_commands.empty?

          agg.commands.concat(new_commands)
          agg.events.concat(new_events)
          load_command_classes(agg, new_commands, new_events, mod_name)
          rewire_aggregate(runtime, agg, mod)
        end
      end

      # Build CRUD command + event IR objects for missing verbs.
      #
      # @param agg [Structure::Aggregate] the aggregate to enrich
      # @return [Array<Array>] [new_commands, new_events]
      def self.generate_stubs(agg)
        existing = agg.commands.map(&:name).to_set
        commands = []
        events   = []

        CRUD_PREFIXES.each do |verb|
          cmd_name = "#{verb}#{agg.name}"
          next if existing.include?(cmd_name)
          next if verb == "Read" # Read is handled by repository, not a command

          cmd_attrs, cmd_refs = attrs_for(verb, agg)
          cmd = Behavior::Command.new(name: cmd_name, attributes: cmd_attrs, references: cmd_refs)
          event = build_event(cmd, agg)
          commands << cmd
          events << event
        end

        [commands, events]
      end

      # Determine attributes and references for a generated CRUD command.
      #
      # @param verb [String] "Create", "Update", or "Delete"
      # @param agg [Structure::Aggregate] the aggregate
      # @return [Array] [attributes, references]
      def self.attrs_for(verb, agg)
        case verb
        when "Create"
          attrs = agg.attributes.reject { |a| reserved?(a.name) }.map do |a|
            Structure::Attribute.new(name: a.name, type: a.type, list: a.list?)
          end
          [attrs, []]
        when "Update"
          snake = HecksTemplating::NamingHelpers.instance_method(:domain_snake_name)
            .bind_call(self, agg.name)
          ref = Structure::Reference.new(name: snake.to_sym, type: agg.name)
          attrs = agg.attributes.reject { |a| reserved?(a.name) }.map do |a|
            Structure::Attribute.new(name: a.name, type: a.type, list: a.list?)
          end
          [attrs, [ref]]
        when "Delete"
          snake = HecksTemplating::NamingHelpers.instance_method(:domain_snake_name)
            .bind_call(self, agg.name)
          ref = Structure::Reference.new(name: snake.to_sym, type: agg.name)
          [[], [ref]]
        else
          [[], []]
        end
      end

      # Build a domain event from a command, mirroring AggregateBuilder's inference.
      #
      # @param cmd [Behavior::Command] the command
      # @param agg [Structure::Aggregate] the parent aggregate
      # @return [Behavior::DomainEvent]
      def self.build_event(cmd, agg)
        aggregate_id_attr = Structure::Attribute.new(name: :aggregate_id, type: String)
        event_attrs = [aggregate_id_attr] + cmd.attributes.dup
        agg.attributes.each do |aa|
          next if event_attrs.any? { |ea| ea.name == aa.name }
          event_attrs << aa
        end
        event_refs = cmd.references.dup
        agg.references.each do |ar|
          next if event_refs.any? { |er| er.name == ar.name }
          event_refs << ar
        end
        Behavior::DomainEvent.new(
          name: cmd.event_names.first,
          attributes: event_attrs,
          references: event_refs
        )
      end

      # Generate and eval Ruby command classes for the new stubs.
      #
      # @param agg [Structure::Aggregate] the aggregate
      # @param commands [Array<Behavior::Command>] new commands
      # @param events [Array<Behavior::DomainEvent>] corresponding events
      # @param mod_name [String] the domain module name
      # @return [void]
      def self.load_command_classes(agg, commands, events, mod_name)
        commands.each_with_index do |cmd, i|
          event = events[i]
          event_source = Generators::Domain::EventGenerator.new(
            event, domain_module: mod_name, aggregate_name: agg.name
          ).generate
          RubyVM::InstructionSequence.compile(event_source, "crud_event_#{cmd.name}").eval

          source = if cmd.name.start_with?("Delete")
            delete_command_source(cmd, event, agg, mod_name)
          else
            Generators::Domain::CommandGenerator.new(
              cmd, domain_module: mod_name, aggregate_name: agg.name,
              aggregate: agg, event: event
            ).generate
          end
          RubyVM::InstructionSequence.compile(source, "crud_cmd_#{cmd.name}").eval
        end
      end

      # Generate source for a delete command that removes from the repository.
      #
      # @return [String] Ruby source code
      def self.delete_command_source(cmd, event, agg, mod_name)
        ref_name = cmd.references.first.name
        <<~RUBY
          module #{mod_name}
            class #{agg.name}
              module Commands
                class #{cmd.name}
                  include Hecks::Command
                  emits "#{event.name}"
                  attr_reader :#{ref_name}
                  def initialize(#{ref_name}: nil)
                    @#{ref_name} = #{ref_name}
                  end
                  def call
                    _id = #{ref_name}.respond_to?(:id) ? #{ref_name}.id : #{ref_name}
                    existing = repository.find(_id)
                    raise #{mod_name}::Error, "#{agg.name} not found: \#{_id}" unless existing
                    repository.delete(_id)
                    existing
                  end
                  private
                  def persist_aggregate; end # already deleted in call
                end
              end
            end
          end
        RUBY
      end

      # Re-wire command and persistence ports after injecting new commands.
      #
      # @param runtime [Hecks::Runtime] the runtime
      # @param agg [Structure::Aggregate] the aggregate
      # @param mod [Module] the domain module
      # @return [void]
      def self.rewire_aggregate(runtime, agg, mod)
        agg_class = mod.const_get(
          HecksTemplating::NamingHelpers.instance_method(:domain_constant_name)
            .bind_call(self, agg.name)
        )
        repo = runtime[agg.name]
        bus = runtime.command_bus

        defaults = agg.attributes.each_with_object({}) do |attr, h|
          h[attr.name] = attr.list? ? [] : nil
        end

        Commands.bind(agg_class, agg, bus, repo, defaults)
      end

      def self.reserved?(name)
        Hecks::Utils::RESERVED_AGGREGATE_ATTRS.include?(name.to_s)
      end
      private_class_method :reserved?
    end
  end
end

Hecks.register_capability(:crud) { |runtime| Hecks::Capabilities::Crud.apply(runtime) }
