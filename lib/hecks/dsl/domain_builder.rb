# Hecks::DSL::DomainBuilder
#
# Top-level DSL builder for domain definitions. Collects aggregate definitions
# and domain-level policies, then builds a DomainModel::Structure::Domain.
# Enforces unique aggregate names. Domain-level policies are cross-aggregate
# reactive policies defined outside any aggregate block.
#
#   Hecks.domain "Banking" do
#     aggregate "Loan" do ... end
#     aggregate "Account" do ... end
#
#     policy "DisburseFunds" do
#       on "IssuedLoan"
#       trigger "Deposit"
#       map principal: :amount
#     end
#   end
#
module Hecks
  module DSL
    class DomainBuilder
      include AttributeCollector

      def initialize(name)
        @name = name
        @aggregates = []
        @policies = []
        @services = []
        @views = []
        @workflows = []
        @attributes = []
        @tenancy = nil
        @event_subscribers = []
      end

      def tenancy(strategy)
        @tenancy = strategy.to_sym
      end

      def service(name, &block)
        builder = ServiceBuilder.new(name)
        builder.instance_eval(&block) if block
        @services << builder.build
      end

      def on_event(event_name, &block)
        @event_subscribers << { event_name: event_name.to_s, block: block }
      end

      def aggregate(name, &block)
        if @aggregates.any? { |a| a.name == name }
          raise ArgumentError, "Duplicate aggregate name: #{name}"
        end

        builder = AggregateBuilder.new(name)
        begin
          builder.instance_eval(&block) if block
        rescue Hecks::Error
          raise
        rescue => e
          raise Hecks::ValidationError, "Error in aggregate '#{name}': #{e.message}"
        end
        @aggregates << builder.build
      end

      def policy(name, &block)
        builder = PolicyBuilder.new(name)
        builder.instance_eval(&block) if block
        @policies << builder.build
      end

      def view(name, &block)
        builder = ReadModelBuilder.new(name)
        builder.instance_eval(&block) if block
        @views << builder.build
      end

      def workflow(name, &block)
        builder = WorkflowBuilder.new(name)
        builder.instance_eval(&block) if block
        @workflows << builder.build
      end

      def build
        DomainModel::Structure::Domain.new(
          name: @name, aggregates: @aggregates, policies: @policies,
          services: @services, views: @views, workflows: @workflows,
          tenancy: @tenancy, event_subscribers: @event_subscribers
        )
      end
    end
  end
end
