# Hecks::DomainModel::ExternalSystem
#
# Represents an external system that a command interacts with. Captured
# during Event Storming as pink stickies -- third-party services, APIs,
# or legacy systems outside the domain boundary.
#
# Part of the DomainModel IR layer. Does not generate code -- serves as
# metadata for documentation and integration planning.
#
#   external = ExternalSystem.new(name: "Stripe")
#   external.name  # => "Stripe"
#
module Hecks
  module DomainModel
    class ExternalSystem
      attr_reader :name

      def initialize(name:)
        @name = name
      end
    end
  end
end
