# Hecks::Generators::Domain::EntityGenerator
#
# Generates mutable sub-entity classes that include Hecks::Model. Entities
# have UUID identity, identity-based equality, and are NOT frozen -- unlike
# value objects. Supports invariant checks and list attributes.
# Part of Generators::Domain, consumed by DomainGemGenerator and InMemoryLoader.
#
#   gen = EntityGenerator.new(entity, domain_module: "BankingDomain", aggregate_name: "Account")
#   gen.generate  # => "module BankingDomain\n  class Account\n    class LedgerEntry\n  ..."
#
module Hecks
  module Generators
    module Domain
    class EntityGenerator

      def initialize(entity, domain_module:, aggregate_name:)
        @entity = entity
        @domain_module = domain_module
        @aggregate_name = aggregate_name
      end

      def generate
        lines = []
        lines << "require 'hecks/model'"
        lines << ""
        lines << "module #{@domain_module}"
        lines << "  class #{@aggregate_name}"
        lines << "    class #{@entity.name}"
        lines << "      include Hecks::Model"
        lines << ""
        @entity.attributes.each do |attr|
          lines << "      attribute #{attribute_declaration(attr)}"
        end
        unless @entity.invariants.empty?
          lines << ""
          lines << "      private"
          lines << ""
          lines.concat(invariant_lines)
        end
        lines << "    end"
        lines << "  end"
        lines << "end"
        lines.join("\n") + "\n"
      end

      private

      def attribute_declaration(attr)
        parts = [":#{attr.name}"]
        if attr.list?
          parts << "default: []"
          parts << "freeze: true"
        elsif attr.default
          parts << "default: #{attr.default.inspect}"
        end
        parts.join(", ")
      end

      def invariant_lines
        if @entity.invariants.empty?
          return ["      def check_invariants!; end"]
        end

        lines = []
        lines << "      def check_invariants!"
        @entity.invariants.each do |inv|
          lines << "        raise #{@domain_module}::InvariantError, #{inv.message.inspect} unless instance_eval(&#{source_from_block(inv.block)})"
        end
        lines << "      end"
        lines
      end

      def source_from_block(block)
        "proc { #{Hecks::Utils.block_source(block)} }"
      end
    end
    end
  end
end
