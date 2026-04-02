module Hecks
  class Workshop

    # Hecks::Workshop::NaturalLanguageInterpreter
    #
    # Translates natural language domain editing phrases into workshop DSL
    # calls. Supports common modeling actions like adding aggregates,
    # attributes, commands, and references. Degrades gracefully by returning
    # nil for unrecognized phrases.
    #
    #   interp = NaturalLanguageInterpreter.new(workshop_runner)
    #   interp.interpret("add an aggregate called Pizza")
    #   interp.interpret("give Pizza a name attribute of type String")
    #
    class NaturalLanguageInterpreter
      # Patterns matched against natural language input.
      # Each entry is [regex, handler_method_symbol].
      PATTERNS = [
        [/add (?:an? )?aggregate (?:called |named )?(\w+)/i, :add_aggregate],
        [/(?:add|give) (\w+) (?:an? )?(?:attribute )?(?:called |named )?(\w+)(?: of type (\w+))?/i, :add_attribute],
        [/add (?:a )?command (\w+) (?:to|on) (\w+)/i, :add_command],
        [/(\w+) references (\w+)/i, :add_reference],
        [/remove (?:aggregate )?(\w+)/i, :remove_aggregate],
        [/validate/i, :validate],
        [/build/i, :build],
        [/save/i, :save],
        [/describe|show|preview/i, :describe]
      ].freeze

      # @param runner [WorkshopRunner] the workshop runner to delegate to
      def initialize(runner)
        @runner = runner
      end

      # Interpret a natural language phrase and execute the corresponding
      # workshop action.
      #
      # @param phrase [String] natural language input
      # @return [Object, nil] result of the action, or nil if unrecognized
      def interpret(phrase)
        PATTERNS.each do |pattern, handler|
          match = phrase.match(pattern)
          next unless match
          return send(handler, match)
        end
        nil
      end

      private

      def add_aggregate(match)
        name = match[1]
        @runner.aggregate(name)
      end

      def add_attribute(match)
        agg_name = match[1]
        attr_name = match[2]
        type_name = match[3] || "String"
        type = resolve_type(type_name)

        handle = @runner.aggregate(agg_name)
        handle.send(attr_name.to_sym, type) if handle.respond_to?(attr_name.to_sym)
        "Added #{attr_name} (#{type_name}) to #{agg_name}"
      end

      def add_command(match)
        cmd_name = match[1]
        agg_name = match[2]
        handle = @runner.aggregate(agg_name)
        handle.send(Hecks::Utils.underscore(cmd_name).to_sym) if handle
        "Added command #{cmd_name} to #{agg_name}"
      end

      def add_reference(match)
        from = match[1]
        to = match[2]
        handle = @runner.aggregate(from)
        handle.reference(to) if handle.respond_to?(:reference)
        "Added reference from #{from} to #{to}"
      end

      def remove_aggregate(match)
        name = match[1]
        @runner.remove(name)
      end

      def validate(_match)
        @runner.validate
      end

      def build(_match)
        @runner.build
      end

      def save(_match)
        @runner.save
      end

      def describe(_match)
        @runner.describe
      end

      def resolve_type(name)
        case name.downcase
        when "string"  then String
        when "integer", "int" then Integer
        when "float"   then Float
        when "date"    then Date
        when "boolean", "bool" then String
        else String
        end
      end
    end
  end
end
