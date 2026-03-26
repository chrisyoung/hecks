# Hecks::DomainModel::Behavior::Command
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
      attr_reader :name, :attributes, :handler, :guard_name, :read_models,
                  :external_systems, :actors, :call_body, :sets,
                  :preconditions, :postconditions

      def initialize(name:, attributes: [], handler: nil, guard_name: nil,
                     read_models: [], external_systems: [], actors: [],
                     call_body: nil, sets: {}, preconditions: [], postconditions: [])
        @name = name
        @attributes = attributes
        @handler = handler
        @guard_name = guard_name
        @read_models = read_models
        @external_systems = external_systems
        @actors = actors
        @call_body = call_body
        @sets = sets
        @preconditions = preconditions
        @postconditions = postconditions
      end

      IRREGULAR_VERBS = {
        "Send" => "Sent", "Build" => "Built", "Buy" => "Bought",
        "Run" => "Ran", "Set" => "Set", "Put" => "Put",
        "Cut" => "Cut", "Hold" => "Held", "Keep" => "Kept",
        "Leave" => "Left", "Make" => "Made", "Pay" => "Paid",
        "Sell" => "Sold", "Tell" => "Told", "Think" => "Thought",
        "Find" => "Found", "Give" => "Gave", "Get" => "Got",
        "Spend" => "Spent", "Lend" => "Lent", "Lose" => "Lost",
        "Win" => "Won", "Write" => "Wrote", "Read" => "Read",
        "Shut" => "Shut", "Hit" => "Hit", "Split" => "Split",
        "Bind" => "Bound", "Bring" => "Brought", "Catch" => "Caught",
        "Choose" => "Chose", "Drive" => "Drove", "Feed" => "Fed",
        "Hear" => "Heard", "Lead" => "Led", "Meet" => "Met",
        "Ride" => "Rode", "Ring" => "Rang", "Rise" => "Rose",
        "Seek" => "Sought", "Shake" => "Shook", "Show" => "Showed",
        "Speak" => "Spoke", "Steal" => "Stole", "Take" => "Took",
        "Teach" => "Taught", "Throw" => "Threw", "Understand" => "Understood",
        "Wake" => "Woke", "Wear" => "Wore", "Withdraw" => "Withdrew",
        "Open" => "Opened", "Offer" => "Offered", "Listen" => "Listened",
        "Enter" => "Entered", "Order" => "Ordered", "Deliver" => "Delivered",
      }.freeze

      # Multi-syllable verbs whose final consonant doubles in past tense.
      DOUBLE_FINAL = %w[
        Submit Admit Permit Commit Emit Omit Remit Transmit
        Refer Confer Defer Infer Prefer Transfer
        Occur Recur Incur Concur
        Compel Expel Repel Propel
        Control Patrol Enrol Fulfil
        Begin Regret Abet Embed Equip
      ].to_set.freeze

      def inferred_event_name
        verb, *rest = name.split(/(?=[A-Z])/)
        past_tense = if IRREGULAR_VERBS.key?(verb)
                       IRREGULAR_VERBS[verb]
                     elsif verb =~ /[^aeiou]y$/i
                       verb.sub(/y$/i, "ied")
                     elsif verb =~ /e$/
                       "#{verb}d"
                     elsif DOUBLE_FINAL.include?(verb) || verb =~ /\A[A-Z][^aeiou]*[aeiou][^aeiouwxy]\z/
                       "#{verb}#{verb[-1]}ed"
                     else
                       "#{verb}ed"
                     end
        rest.unshift(past_tense).join
      end
    end
    end
  end
end
