# Hecks::DomainModel::Command
#
# Intermediate representation of a domain command -- an intent to change state.
# Each command carries attributes, optional read models, external systems,
# and actors. Can infer a corresponding event name by converting the verb
# to past tense (CreatePizza -> CreatedPizza).
#
# Part of the DomainModel IR layer. Built by CommandBuilder or EventStorm
# parser, consumed by CommandGenerator and event inference in AggregateBuilder.
#
#   cmd = Command.new(name: "CreatePizza", attributes: [Attribute.new(name: :name, type: String)])
#   cmd.inferred_event_name  # => "CreatedPizza"
#
module Hecks
  module DomainModel
    module Behavior
    class Command
      attr_reader :name, :attributes, :handler, :read_models, :external_systems, :actors

      def initialize(name:, attributes: [], handler: nil, read_models: [], external_systems: [], actors: [])
        @name = name
        @attributes = attributes
        @handler = handler
        @read_models = read_models
        @external_systems = external_systems
        @actors = actors
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
end
