# Hecks::Generators::SpecGenerator
#
# Generates RSpec test scaffolds for domain objects. Creates specs for
# aggregates, value objects, commands, and events. Supports context-qualified
# class names for multi-context domains.
#
#   gen = SpecGenerator.new(domain)
#   gen.generate_aggregate_spec(agg)                          # PizzasDomain::Pizza
#   gen.generate_aggregate_spec(agg, context_module: "Ordering")  # PizzasDomain::Ordering::Order
#
require_relative "spec_helpers"

module Hecks
  module Generators
    module Infrastructure
    class SpecGenerator
      include SpecHelpers

      def initialize(domain)
        @domain = domain
      end

      def generate_spec_helper
        gem_name = @domain.gem_name

        <<~RUBY
          require "#{gem_name}"

          RSpec.configure do |config|
            config.expect_with :rspec do |expectations|
              expectations.include_chain_clauses_in_custom_matcher_descriptions = true
            end

            config.mock_with :rspec do |mocks|
              mocks.verify_partial_doubles = true
            end

            config.filter_run_when_matching :focus
            config.order = :random
          end
        RUBY
      end

      def generate_aggregate_spec(aggregate, context_module: nil)
        fqn = full_class_name(aggregate.name, context_module)

        <<~RUBY
          require "spec_helper"

          RSpec.describe #{fqn} do
            subject(:#{Hecks::Utils.underscore(aggregate.name)}) do
              described_class.new(#{example_args(aggregate)})
            end

            describe "#initialize" do
              it "creates a #{aggregate.name} with an id" do
                expect(#{Hecks::Utils.underscore(aggregate.name)}.id).not_to be_nil
              end

          #{attribute_specs(aggregate)}
            end

          #{validation_specs(aggregate)}
          #{equality_spec(aggregate)}
          end
        RUBY
      end

      def generate_value_object_spec(value_object, aggregate, context_module: nil)
        fqn = full_class_name("#{aggregate.name}::#{value_object.name}", context_module)

        <<~RUBY
          require "spec_helper"

          RSpec.describe #{fqn} do
            subject(:#{Hecks::Utils.underscore(value_object.name)}) do
              described_class.new(#{example_args(value_object)})
            end

            describe "#initialize" do
              it "creates a frozen #{value_object.name}" do
                expect(#{Hecks::Utils.underscore(value_object.name)}).to be_frozen
              end
            end

            describe "equality" do
              it "is equal to another #{value_object.name} with the same attributes" do
                other = described_class.new(#{example_args(value_object)})
                expect(#{Hecks::Utils.underscore(value_object.name)}).to eq(other)
              end
            end

          #{invariant_specs(value_object)}
          end
        RUBY
      end

      def generate_command_spec(command, aggregate, context_module: nil)
        fqn = full_class_name("#{aggregate.name}::Commands::#{command.name}", context_module)

        <<~RUBY
          require "spec_helper"

          RSpec.describe #{fqn} do
            subject(:command) do
              described_class.new(#{example_args(command)})
            end

            describe "#initialize" do
              it "creates a frozen command" do
                expect(command).to be_frozen
              end

          #{command.attributes.map { |a| "    it \"has #{a.name}\" do\n      expect(command.#{a.name}).not_to be_nil\n    end" }.join("\n\n")}
            end
          end
        RUBY
      end

      def generate_event_spec(event, aggregate, context_module: nil)
        fqn = full_class_name("#{aggregate.name}::Events::#{event.name}", context_module)

        <<~RUBY
          require "spec_helper"

          RSpec.describe #{fqn} do
            subject(:event) do
              described_class.new(#{example_args(event)})
            end

            describe "#initialize" do
              it "creates a frozen event" do
                expect(event).to be_frozen
              end

              it "records occurred_at" do
                expect(event.occurred_at).to be_a(Time)
              end
            end
          end
        RUBY
      end
    end
    end
  end
end
