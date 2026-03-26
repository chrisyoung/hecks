# Hecks::Generators::Domain::LifecycleGenerator
#
# Generates a Lifecycle class for an aggregate's state machine. Contains
# the field name, default state, transitions (with from-guards), state
# constants, and predicate methods. Implements call for uniform interface.
#
#   gen = LifecycleGenerator.new(lifecycle, domain_module: "ModelRegistryDomain", aggregate_name: "AiModel")
#   gen.generate
#
module Hecks
  module Generators
    module Domain
    class LifecycleGenerator

      def initialize(lifecycle, domain_module:, aggregate_name:)
        @lifecycle = lifecycle
        @domain_module = domain_module
        @aggregate_name = aggregate_name
      end

      def generate
        lines = []
        lines << "module #{@domain_module}"
        lines << "  class #{@aggregate_name}"
        lines << "    class Lifecycle"
        lines << "      FIELD = :#{@lifecycle.field} unless defined?(FIELD)"
        lines << "      DEFAULT = #{@lifecycle.default.inspect} unless defined?(DEFAULT)"
        lines << "      STATES = [#{@lifecycle.states.map(&:inspect).join(', ')}].freeze unless defined?(STATES)"
        lines << ""
        lines << "      TRANSITIONS = {"
        @lifecycle.transitions.each do |cmd_name, target_or_hash|
          if target_or_hash.is_a?(Hash)
            from = target_or_hash[:from]
            target = target_or_hash[:target]
            lines << "        #{cmd_name.inspect} => { target: #{target.inspect}, from: #{from.inspect} },"
          else
            lines << "        #{cmd_name.inspect} => #{target_or_hash.inspect},"
          end
        end
        lines << "      }.freeze unless defined?(TRANSITIONS)"
        lines << ""
        lines << "      attr_reader :target"
        lines << ""
        lines << "      def call(current_state, command_name)"
        lines << "        entry = TRANSITIONS[command_name]"
        lines << "        @target = entry.is_a?(Hash) ? entry[:target] : entry"
        lines << "        @target ||= current_state"
        lines << "        self"
        lines << "      end"
        lines << ""
        @lifecycle.states.each do |state|
          lines << "      def #{state}?; @target == #{state.inspect}; end"
        end
        lines << "    end"
        lines << "  end"
        lines << "end"
        lines.join("\n") + "\n"
      end
    end
    end
  end
end
