# Hecks::Generators::Domain::CommandGenerator
#
# Generates command classes with emits declaration and a call method
# containing only domain logic. The Hecks::Command mixin handles
# handler, event emission, and recording.
#
#   gen = CommandGenerator.new(cmd, domain_module: "PizzasDomain",
#     aggregate_name: "Pizza", aggregate: agg, event: evt)
#   gen.generate
#
module Hecks
  module Generators
    module Domain
    class CommandGenerator

      def initialize(command, domain_module:, aggregate_name:, aggregate: nil, event: nil)
        @command = command
        @domain_module = domain_module
        @aggregate_name = aggregate_name
        @aggregate = aggregate
        @event = event
        @has_keyword_attrs = @command.attributes.any? { |a| Hecks::Utils.ruby_keyword?(a.name) }
        @is_create = @command.name.start_with?("Create")
      end

      def generate
        lines = []
        lines << "module #{@domain_module}"
        lines << "  class #{@aggregate_name}"
        lines << "    module Commands"
        lines << "      class #{@command.name}"
        lines << "        emits \"#{@event.name}\"" if @event
        lines << ""
        lines << "        attr_reader #{@command.attributes.map { |a| ":#{a.name}" }.join(", ")}"
        lines << ""
        lines.concat(initializer_lines)
        lines << ""
        lines.concat(call_lines) if @aggregate && @event
        lines << "      end"
        lines << "    end"
        lines << "  end"
        lines << "end"
        lines.join("\n") + "\n"
      end

      private

      def initializer_lines
        lines = []
        if @has_keyword_attrs
          lines << "        def initialize(**kwargs)"
          @command.attributes.each do |attr|
            lines << "          @#{attr.name} = kwargs[:#{attr.name}]"
          end
        else
          lines << "        def initialize(#{constructor_params})"
          @command.attributes.each do |attr|
            lines << "          @#{attr.name} = #{attr.name}"
          end
        end
        lines << "        end"
        lines
      end

      def call_lines
        lines = []
        lines << "        def call"
        if @is_create
          lines.concat(create_body)
        else
          lines.concat(update_body)
        end
        lines << "        end"
        lines
      end

      def create_body
        ["          #{@aggregate_name}.new(#{create_constructor_args})"]
      end

      def update_body
        lines = []
        id_attr = @command.attributes.find { |a| a.name.to_s.end_with?("_id") }
        if id_attr
          lines << "          existing = repository.find(#{id_attr.name})"
          lines << "          if existing"
          lines << "            #{@aggregate_name}.new(#{update_constructor_args})"
          lines << "          else"
          lines << "            #{@aggregate_name}.new(#{create_constructor_args})"
          lines << "          end"
        else
          lines << "          #{@aggregate_name}.new(#{create_constructor_args})"
        end
        lines
      end

      def create_constructor_args
        parts = []
        agg_attrs.each do |a|
          cmd_attr = @command.attributes.find { |c| c.name == a.name }
          parts << "#{a.name}: #{a.name}" if cmd_attr
        end
        parts.join(", ")
      end

      def update_constructor_args
        parts = ["id: existing.id"]
        agg_attrs.each do |a|
          cmd_attr = @command.attributes.find { |c| c.name == a.name }
          if cmd_attr
            parts << "#{a.name}: #{a.name}"
          else
            parts << "#{a.name}: existing.#{a.name}"
          end
        end
        parts.join(", ")
      end

      def agg_attrs
        return [] unless @aggregate
        @aggregate.attributes.reject { |a| Hecks::Utils::RESERVED_AGGREGATE_ATTRS.include?(a.name.to_s) }
      end

      def constructor_params
        @command.attributes.map { |attr| "#{attr.name}: nil" }.join(", ")
      end
    end
    end
  end
end
