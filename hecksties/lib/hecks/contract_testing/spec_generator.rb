# = Hecks::ContractTesting::SpecGenerator
#
# Generates contract spec files for every aggregate in a domain.
# Each spec file includes the shared "hecks repository contract"
# examples, pre-wired with the domain's memory adapter and a factory
# lambda that constructs a valid aggregate instance.
#
# == Usage
#
#   gen = Hecks::ContractTesting::SpecGenerator.new(domain, output_dir: "spec/contracts")
#   paths = gen.generate  # => ["spec/contracts/pizza_repository_contract_spec.rb", ...]
#
module Hecks
  module ContractTesting
    class SpecGenerator
      include HecksTemplating::NamingHelpers

      # @param domain [Hecks::DomainModel::Structure::Domain] the domain IR
      # @param output_dir [String] directory to write spec files into
      def initialize(domain, output_dir:)
        @domain = domain
        @output_dir = output_dir
      end

      # Generates one contract spec file per aggregate.
      #
      # @return [Array<String>] absolute paths of written files
      def generate
        FileUtils.mkdir_p(@output_dir)
        @domain.aggregates.map { |agg| write_spec(agg) }
      end

      private

      def write_spec(aggregate)
        safe = domain_constant_name(aggregate.name)
        snake = domain_snake_name(safe)
        mod = domain_constant_name(@domain.name) + "Domain"
        path = File.join(@output_dir, "#{snake}_repository_contract_spec.rb")

        attrs = aggregate.attributes.map do |attr|
          "#{attr.name}: #{sample_value(attr.type)}"
        end.join(", ")

        content = spec_template(mod, safe, attrs)
        File.write(path, content)
        path
      end

      def spec_template(mod, aggregate, attrs)
        <<~RUBY
          require "hecks"
          require "hecks/contract_testing"

          RSpec.describe "#{aggregate} repository contract" do
            let(:domain) do
              Hecks.domain "#{@domain.name}" do
          #{domain_block_body}
              end
            end

            before { @app = Hecks.load(domain) }

            include_examples "hecks repository contract",
              adapter: -> { #{mod}::Adapters::#{aggregate}MemoryRepository.new },
              factory: -> { #{mod}::#{aggregate}.new(#{attrs}) }
          end
        RUBY
      end

      def domain_block_body
        @domain.aggregates.map do |agg|
          lines = []
          lines << "      aggregate \"#{agg.name}\" do"
          agg.attributes.each do |attr|
            lines << "        attribute :#{attr.name}, #{attr.type}"
          end
          agg.commands.each do |cmd|
            lines << "        command \"#{cmd.name}\" do"
            cmd.attributes.each do |attr|
              lines << "          attribute :#{attr.name}, #{attr.type}"
            end
            lines << "        end"
          end
          lines << "      end"
          lines.join("\n")
        end.join("\n")
      end

      def sample_value(type)
        case type.to_s
        when "Integer" then "1"
        when "Float"   then "1.0"
        when "Boolean" then "true"
        when "Date"    then "Date.today"
        when "DateTime" then "DateTime.now"
        else '"test"'
        end
      end
    end
  end
end
