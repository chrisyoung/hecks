# Hecks::Generators::SqlAdapterGenerator
#
# Generates SQL-backed repository implementations with find, save, delete,
# and all operations. Handles join tables for list-type value objects.
#
# Part of the Generators layer. Invoked by the CLI's `generate:sql` command
# to produce SQL adapter classes alongside the schema migration.
#
#   gen = SqlAdapterGenerator.new(agg, domain_module: "PizzasDomain")
#   gen.generate  # => "module PizzasDomain\n  module Adapters\n    class PizzaSqlRepository\n  ..."
#
require_relative "sql_builder"

module Hecks
  module Generators
    class SqlAdapterGenerator
      include SqlBuilder

      def initialize(aggregate, domain_module:)
        @aggregate = aggregate
        @domain_module = domain_module
      end

      def generate
        lines = []
        lines << "require \"time\""
        lines << ""
        lines << "module #{@domain_module}"
        lines << "  module Adapters"
        lines << "    class #{@aggregate.name}SqlRepository"
        lines << "      include Ports::#{@aggregate.name}Repository"
        lines << ""
        lines << "      def initialize(connection)"
        lines << "        @connection = connection"
        lines << "      end"
        lines << ""
        lines << "      def find(id)"
        lines << "        row = @connection.execute("
        lines << "          \"SELECT * FROM #{table_name} WHERE id = ?\", [id]"
        lines << "        ).first"
        lines << "        return nil unless row"
        lines << "        build(row)"
        lines << "      end"
        lines << ""
        lines << "      def save(#{snake_name})"
        lines << "        if find(#{snake_name}.id)"
        lines << "          update(#{snake_name})"
        lines << "        else"
        lines << "          insert(#{snake_name})"
        lines << "        end"
        lines << "        #{snake_name}"
        lines << "      end"
        lines << ""
        lines << "      def delete(id)"
        lines.concat(delete_vo_lines)
        lines << "        @connection.execute("
        lines << "          \"DELETE FROM #{table_name} WHERE id = ?\", [id]"
        lines << "        )"
        lines << "      end"
        lines << ""
        lines << "      def all"
        lines << "        rows = @connection.execute(\"SELECT * FROM #{table_name}\")"
        lines << "        rows.map { |row| build(row) }"
        lines << "      end"
        lines << ""
        lines << "      def count"
        lines << "        row = @connection.execute(\"SELECT COUNT(*) FROM #{table_name}\").first"
        lines << "        row.is_a?(Hash) ? row.values.first : row[0]"
        lines << "      end"
        lines << ""
        lines << "      private"
        lines << ""
        lines.concat(insert_lines)
        lines << ""
        lines.concat(update_lines)
        lines << ""
        lines.concat(build_lines)
        lines << "    end"
        lines << "  end"
        lines << "end"
        lines.join("\n") + "\n"
      end

      private

      def table_name
        Hecks::Utils.underscore(@aggregate.name) + "s"
      end

      def snake_name
        Hecks::Utils.underscore(@aggregate.name)
      end

      def scalar_attributes
        @aggregate.attributes.reject(&:list?)
      end

      def list_value_objects
        @aggregate.value_objects.select do |vo|
          @aggregate.attributes.any? { |a| a.list? && a.type.to_s == vo.name }
        end
      end
    end
  end
end
