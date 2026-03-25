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
        @attributes = []
        @tenancy = nil
      end

      def tenancy(strategy)
        @tenancy = strategy.to_sym
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

      def build
        DomainModel::Structure::Domain.new(
          name: @name, aggregates: @aggregates, policies: @policies, tenancy: @tenancy
        )
      end
    end
  end
end
