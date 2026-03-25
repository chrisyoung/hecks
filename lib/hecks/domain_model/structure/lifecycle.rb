# Hecks::DomainModel::Structure::Lifecycle
#
# State machine definition for an aggregate. Declares which field tracks
# status, its default value, and which commands trigger which transitions.
# Supports optional `from:` constraints to enforce valid source states.
#
#   Lifecycle.new(field: :status, default: "draft",
#     transitions: { "ApproveModel" => { target: "approved", from: "draft" } })
#
module Hecks
  module DomainModel
    module Structure
      class Lifecycle
        attr_reader :field, :default, :transitions

        def initialize(field:, default:, transitions: {})
          @field = field.to_sym
          @default = default.to_s
          @transitions = transitions
        end

        def states
          ([default] + transitions.values.map { |v| v.is_a?(Hash) ? v[:target] : v }).uniq
        end

        def target_for(command_name)
          entry = transitions[command_name]
          entry.is_a?(Hash) ? entry[:target] : entry
        end

        def from_for(command_name)
          entry = transitions[command_name]
          entry.is_a?(Hash) ? entry[:from] : nil
        end
      end
    end
  end
end
