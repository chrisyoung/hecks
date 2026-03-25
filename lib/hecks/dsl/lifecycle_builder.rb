# Hecks::DSL::LifecycleBuilder
#
# DSL builder for state machine declarations on aggregates. Collects
# command-to-state transitions and builds a Lifecycle IR object.
#
#   builder = LifecycleBuilder.new(:status, default: "draft")
#   builder.transition "ApproveModel" => "approved"
#   builder.transition "SuspendModel" => "suspended"
#   lifecycle = builder.build
#
module Hecks
  module DSL
    class LifecycleBuilder
      def initialize(field, default:)
        @field = field
        @default = default
        @transitions = {}
      end

      def transition(mapping)
        from = mapping.delete(:from)
        mapping.each do |command_name, target_state|
          if from
            @transitions[command_name.to_s] = { target: target_state.to_s, from: from.to_s }
          else
            @transitions[command_name.to_s] = target_state.to_s
          end
        end
      end

      def build
        DomainModel::Structure::Lifecycle.new(
          field: @field, default: @default, transitions: @transitions
        )
      end
    end
  end
end
