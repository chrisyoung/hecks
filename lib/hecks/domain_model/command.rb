# Hecks::DomainModel::Command
#
# Intermediate representation of a domain command -- an intent to change state.
# Each command carries attributes and can infer a corresponding event name
# by converting the verb to past tense (CreatePizza -> CreatedPizza).
#
# Part of the DomainModel IR layer. Built by CommandBuilder, consumed by
# CommandGenerator and the event inference logic in AggregateBuilder.
#
#   cmd = Command.new(name: "CreatePizza", attributes: [Attribute.new(name: :name, type: String)])
#   cmd.inferred_event_name  # => "CreatedPizza"
#
module Hecks
  module DomainModel
    class Command
      attr_reader :name, :attributes

      def initialize(name:, attributes: [])
        @name = name
        @attributes = attributes
      end

      def inferred_event_name
        verb, *rest = name.split(/(?=[A-Z])/)
        past_tense = case verb
                     when /e$/  then "#{verb}d"
                     when /[^aeiou]$/  then "#{verb}ed"
                     else "#{verb}ed"
                     end
        rest.unshift(past_tense).join
      end
    end
  end
end
