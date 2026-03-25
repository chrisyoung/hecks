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
        mapping.each { |cmd, state| @transitions[cmd.to_s] = state.to_s }
      end

      def build
        DomainModel::Structure::Lifecycle.new(
          field: @field, default: @default, transitions: @transitions
        )
      end
    end
  end
end
