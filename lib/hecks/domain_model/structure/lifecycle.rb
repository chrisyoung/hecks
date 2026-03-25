# Hecks::DomainModel::Structure::Lifecycle
#
# State machine definition for an aggregate. Declares which field tracks
# status, its default value, and which commands trigger which transitions.
#
#   Lifecycle.new(field: :status, default: "draft",
#     transitions: { "ApproveModel" => "approved", "SuspendModel" => "suspended" })
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
          ([default] + transitions.values).uniq
        end

        def target_for(command_name)
          transitions[command_name]
        end
      end
    end
  end
end
