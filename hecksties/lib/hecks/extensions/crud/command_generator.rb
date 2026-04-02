# Hecks::Crud::CommandGenerator
#
# Introspects aggregate attributes and builds missing CRUD commands
# (Create, Update, Delete) with their corresponding domain events.
# Works at two levels:
#
# 1. +enrich(domain)+ -- mutates the domain IR before +Hecks.load+,
#    adding Command and DomainEvent nodes. InMemoryLoader then generates
#    the Ruby classes normally.
#
# 2. +generate_all+ -- for the +Hecks.boot+ path where the domain is
#    already loaded. Enriches the IR, generates Ruby source in memory,
#    and re-wires the runtime ports.
#
#   Hecks::Crud::CommandGenerator.enrich(domain)
#   app = Hecks.load(domain)
#   Pizza.create(name: "Margherita")
#
require_relative "source_builder"

module Hecks
  module Crud
    module CommandGenerator
      Structure = Hecks::DomainModel::Structure
      Behavior  = Hecks::DomainModel::Behavior

      CRUD_VERBS = %w[Create Update Delete].freeze

      extend HecksTemplating::NamingHelpers

      # Enrich the domain IR with missing CRUD commands.
      # Call this before +Hecks.load+ so InMemoryLoader generates the classes.
      #
      # @param domain [Hecks::DomainModel::Structure::Domain] the domain IR
      # @return [void]
      def self.enrich(domain)
        domain.aggregates.each { |agg| enrich_aggregate(agg) }
      end

      # Generate and wire CRUD commands for an already-loaded domain.
      # Used by the extension hook in +Hecks.boot+.
      #
      # @param domain_mod [Module] the domain module (e.g., PizzasDomain)
      # @param domain [Hecks::DomainModel::Structure::Domain] the domain IR
      # @param runtime [Hecks::Runtime] the booted runtime to re-wire
      # @return [void]
      def self.generate_all(domain_mod, domain, runtime)
        mod_name = domain_mod.name
        domain.aggregates.each do |agg|
          sources = generate_sources(agg, mod_name)
          next if sources.empty?

          sources.each { |src| eval_source(src) }
          runtime.send(:wire_aggregate!, agg.name)
        end
      end

      # Add missing CRUD command/event IR nodes to a single aggregate.
      #
      # @param agg [Hecks::DomainModel::Structure::Aggregate]
      # @return [void]
      def self.enrich_aggregate(agg)
        existing = agg.commands.map(&:name)
        CRUD_VERBS.each do |verb|
          next if existing.include?("#{verb}#{agg.name}")

          cmd_ir, event_ir = build_ir(verb, agg)
          agg.commands << cmd_ir
          agg.events << event_ir
        end
      end

      # Build Command and DomainEvent IR nodes for a CRUD verb.
      #
      # @param verb [String] "Create", "Update", or "Delete"
      # @param agg [Hecks::DomainModel::Structure::Aggregate]
      # @return [Array(Behavior::Command, Behavior::DomainEvent)]
      def self.build_ir(verb, agg)
        attrs = verb == "Delete" ? [] : agg.attributes.map { |a| dup_attribute(a) }
        ref = unless verb == "Create"
          Structure::Reference.new(
            name: domain_snake_name(agg.name).to_sym,
            type: agg.name,
            validate: :exists
          )
        end
        cmd = Behavior::Command.new(
          name: "#{verb}#{agg.name}",
          attributes: attrs,
          references: ref ? [ref] : []
        )
        evt = Behavior::DomainEvent.new(name: cmd.inferred_event_name, attributes: attrs)
        [cmd, evt]
      end

      # Generate Ruby source for missing CRUD commands on a single aggregate.
      # Also enriches the IR if not already done.
      #
      # @param agg [Hecks::DomainModel::Structure::Aggregate]
      # @param mod_name [String]
      # @return [Array<String>] Ruby source strings
      def self.generate_sources(agg, mod_name)
        existing_before = agg.commands.map(&:name)
        enrich_aggregate(agg)
        new_cmds = agg.commands.reject { |c| existing_before.include?(c.name) }
        new_evts = agg.events.last(new_cmds.size)

        new_cmds.zip(new_evts).flat_map do |cmd, evt|
          verb = cmd.name.sub(agg.name, "")
          [
            SourceBuilder.command_source(verb, agg, cmd, evt, mod_name),
            SourceBuilder.event_source(evt, agg, mod_name)
          ]
        end
      end

      # @return [Structure::Attribute]
      def self.dup_attribute(attr)
        Structure::Attribute.new(name: attr.name, type: attr.type)
      end

      # @return [void]
      def self.eval_source(source)
        RubyVM::InstructionSequence.compile(source, "(crud_extension)").eval
      end
    end
  end
end
