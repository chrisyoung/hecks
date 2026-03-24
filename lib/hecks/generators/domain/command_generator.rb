# Hecks::Generators::Domain::CommandGenerator
#
# Generates command classes with an emits declaration and a call method.
# Create commands build a new aggregate; update commands look up an
# existing one by ID and merge changed attributes. Handles Ruby keyword-
# safe attribute names via **kwargs. The Hecks::Command mixin (included
# at load time) provides event emission and handler wiring. Part of
# Generators::Domain, consumed by DomainGemGenerator and SourceBuilder.
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
        attr_syms = @command.attributes.map { |a| ":#{a.name}" }
        if attr_syms.size <= 2
          lines << "        attr_reader #{attr_syms.join(", ")}"
        else
          attr_syms.each { |s| lines << "        attr_reader #{s}" }
        end
        lines << ""
        lines.concat(initializer_lines)
        lines << ""
        if @command.call_body
          lines.concat(custom_call_lines)
        elsif @aggregate && @event
          lines.concat(call_lines)
        end
        lines << "      end"
        lines << "    end"
        lines << "  end"
        lines << "end"
        lines.join("\n") + "\n"
      end

      private

      def custom_call_lines
        source = Hecks::Utils.block_source(@command.call_body)
        lines = ["        def call"]
        source.split("\n").each { |l| lines << "          #{l}" }
        lines << "        end"
        lines
      end

      def initializer_lines
        lines = []
        if @has_keyword_attrs
          lines << "        def initialize(**kwargs)"
          @command.attributes.each do |attr|
            lines << "          @#{attr.name} = kwargs[:#{attr.name}]"
          end
        else
          params = constructor_params
          if params.size <= 2
            lines << "        def initialize(#{params.join(", ")})"
          else
            lines << "        def initialize("
            params.each_with_index do |p, i|
              suffix = i < params.size - 1 ? "," : ""
              lines << "          #{p}#{suffix}"
            end
            lines << "        )"
          end
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
        args = create_constructor_args
        format_new_call("          ", args)
      end

      def update_body
        lines = []
        id_attr = @command.attributes.find { |a| a.name.to_s.end_with?("_id") }
        if id_attr
          lines << "          existing = repository.find(#{id_attr.name})"
          lines << "          if existing"
          lines.concat(format_new_call("            ", update_constructor_args))
          lines << "          else"
          lines.concat(format_new_call("            ", create_constructor_args))
          lines << "          end"
        else
          lines.concat(format_new_call("          ", create_constructor_args))
        end
        lines
      end

      def create_constructor_args
        agg_attrs.each_with_object([]) do |a, parts|
          cmd_attr = @command.attributes.find { |c| c.name == a.name }
          parts << "#{a.name}: #{a.name}" if cmd_attr
        end
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
        parts
      end

      # Format Aggregate.new(...) — inline if ≤2 args, stacked otherwise.
      def format_new_call(indent, args)
        if args.size <= 2
          ["#{indent}#{@aggregate_name}.new(#{args.join(", ")})"]
        else
          lines = ["#{indent}#{@aggregate_name}.new("]
          args.each_with_index do |arg, i|
            comma = i < args.size - 1 ? "," : ""
            lines << "#{indent}  #{arg}#{comma}"
          end
          lines << "#{indent})"
          lines
        end
      end

      def agg_attrs
        return [] unless @aggregate
        @aggregate.attributes.reject { |a| Hecks::Utils::RESERVED_AGGREGATE_ATTRS.include?(a.name.to_s) }
      end

      def constructor_params
        @command.attributes.map { |attr| "#{attr.name}: nil" }
      end
    end
    end
  end
end
