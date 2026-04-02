# Hecks::Workshop::NaturalLanguageInterpreter
#
# Wraps HecksAi::LlmClient with a conversation-scoped prompt for
# incremental domain edits. Translates natural language into DSL
# operations and applies them to the workshop runner.
#
# Degrades gracefully when no API key is set — prints a helpful message
# instead of raising.
#
#   interpreter = NaturalLanguageInterpreter.new(runner)
#   interpreter.interpret("Add a title attribute to Pizza")
#   # => prints the planned operations, then applies them
#
module Hecks
  class Workshop
    class NaturalLanguageInterpreter
      def initialize(runner, client: nil)
        @runner = runner
        @client = client
        @messages = []
      end

      # Interpret a natural language request and apply DSL operations.
      # Returns the list of operations applied, or nil if unavailable.
      def interpret(text)
        unless available?
          puts "Natural language requires ANTHROPIC_API_KEY. Set it and try again."
          return nil
        end

        operations = fetch_operations(text)
        return nil unless operations

        show_plan(operations)
        apply(operations)
        operations
      end

      # Whether the interpreter has a working LLM client.
      def available?
        !!client
      end

      private

      def client
        @client ||= build_client
      end

      def build_client
        key = ENV["ANTHROPIC_API_KEY"]
        return nil unless key && !key.empty?

        require "hecks_ai"
        Hecks::AI::LlmClient.new(api_key: key)
      end

      def fetch_operations(text)
        @messages << { role: "user", content: text }
        body = build_request
        response = client.send(:post, body)
        result = client.send(:extract_tool_result, response)
        ops = result[:operations] || []
        @messages << { role: "assistant", content: "Applied #{ops.size} operations." }
        ops
      rescue RuntimeError => e
        puts "LLM error: #{e.message}"
        nil
      end

      def build_request
        {
          model: client.class::MODEL,
          max_tokens: client.class::MAX_TOKENS,
          system: domain_context,
          tools: [Hecks::AI::Prompts::DomainEdit::TOOL_SCHEMA],
          tool_choice: { type: "tool", name: "edit_domain" },
          messages: @messages
        }
      end

      def domain_context
        base = Hecks::AI::Prompts::DomainEdit::SYSTEM_PROMPT
        workshop = @runner.instance_variable_get(:@workshop)
        return base unless workshop

        aggregates = workshop.aggregate_builders.map do |name, builder|
          attrs = builder.attributes.map { |a| "#{a.name}: #{a.type}" }.join(", ")
          cmds = builder.commands.map(&:name).join(", ")
          "  #{name}(#{attrs}) commands: [#{cmds}]"
        end.join("\n")

        "#{base}\n\nCurrent domain: #{workshop.name}\nAggregates:\n#{aggregates}"
      end

      def show_plan(operations)
        puts ""
        puts "  Plan:"
        operations.each do |op|
          puts "    #{format_operation(op)}"
        end
        puts ""
      end

      def format_operation(op)
        case op[:op]
        when "add_aggregate"
          "Create aggregate #{op[:name]}"
        when "add_attribute"
          "Add #{op[:name]} (#{op[:type] || 'String'}) to #{op[:aggregate]}"
        when "add_command"
          "Add command #{op[:name]} to #{op[:aggregate]}"
        when "add_command_attribute"
          "Add #{op[:name]} (#{op[:type]}) to #{op[:aggregate]}.#{op[:command]}"
        when "add_value_object"
          "Add value object #{op[:name]} to #{op[:aggregate]}"
        when "add_reference"
          "Add reference_to #{op[:target]} on #{op[:aggregate]}"
        when "add_lifecycle"
          "Add lifecycle :#{op[:field]} to #{op[:aggregate]}"
        when "add_transition"
          "Add transition #{op[:command]} => #{op[:target]} on #{op[:aggregate]}"
        when "remove_aggregate"
          "Remove aggregate #{op[:name] || op[:aggregate]}"
        when "remove_attribute"
          "Remove #{op[:name]} from #{op[:aggregate]}"
        when "remove_command"
          "Remove command #{op[:name]} from #{op[:aggregate]}"
        else
          op.inspect
        end
      end

      def apply(operations)
        operations.each { |op| apply_one(op) }
      end

      def apply_one(op)
        case op[:op]
        when "add_aggregate"
          @runner.aggregate(op[:name])
        when "add_attribute"
          handle = @runner.aggregate(op[:name_of_aggregate] || op[:aggregate])
          handle.attr(op[:name], resolve_type(op[:type]))
        when "add_command"
          handle = @runner.aggregate(op[:aggregate])
          handle.command(op[:name])
        when "add_command_attribute"
          handle = @runner.aggregate(op[:aggregate])
          cmd = handle.command(op[:command])
          cmd.attr(op[:name], resolve_type(op[:type]))
        when "add_value_object"
          handle = @runner.aggregate(op[:aggregate])
          attrs = op[:attributes] || []
          handle.value_object(op[:name]) do
            attrs.each { |a| attribute a[:name].to_sym, resolve_type(a[:type]) }
          end
        when "add_reference"
          handle = @runner.aggregate(op[:aggregate])
          handle.reference_to(op[:target])
        when "add_lifecycle"
          handle = @runner.aggregate(op[:aggregate])
          handle.lifecycle(op[:field].to_sym, default: op[:default])
        when "add_transition"
          handle = @runner.aggregate(op[:aggregate])
          handle.transition(op[:command] => op[:target])
        when "remove_aggregate"
          @runner.remove(op[:name] || op[:aggregate])
        when "remove_attribute"
          handle = @runner.aggregate(op[:aggregate])
          handle.remove(op[:name])
        when "remove_command"
          handle = @runner.aggregate(op[:aggregate])
          handle.remove_command(op[:name])
        end
      rescue => e
        puts "  Failed: #{op[:op]} — #{e.message}"
      end

      def resolve_type(type_str)
        return String if type_str.nil? || type_str.empty?

        case type_str
        when "String"   then String
        when "Integer"  then Integer
        when "Float"    then Float
        when "Boolean"  then String  # maps to String in Hecks
        when "Date"     then String
        when "DateTime" then String
        when /\Alist_of\((\w+)\)\z/  then { list: $1 }
        when /\Areference_to\((\w+)\)\z/ then type_str
        else type_str
        end
      end
    end
  end
end
