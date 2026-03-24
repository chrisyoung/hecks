# Hecks::Generators::SQL::SqlMigrationGenerator
#
# Generates CREATE TABLE SQL statements from a domain model. Produces one
# table per aggregate plus join tables for list-type value objects. Part of
# Generators::SQL, invoked by the CLI `hecks domain build` command to produce
# db/schema.sql.
#
#   gen = SqlMigrationGenerator.new(domain)
#   gen.generate  # => "CREATE TABLE pizzas (\n  id VARCHAR(36) PRIMARY KEY,\n  ..."
#
module Hecks
  module Generators
    module SQL
    class SqlMigrationGenerator
      def initialize(domain)
        @domain = domain
      end

      def generate
        tables = []

        @domain.aggregates.each do |agg|
          tables << generate_aggregate_table(agg)

          agg.value_objects.each do |vo|
            # Value objects with list attributes get their own join table
            list_attrs = agg.attributes.select { |a| a.list? && a.type.to_s == vo.name }
            unless list_attrs.empty?
              tables << generate_value_object_table(vo, agg)
            end
          end

          agg.entities.each do |ent|
            # Entities with list attributes get their own table (with id column)
            list_attrs = agg.attributes.select { |a| a.list? && a.type.to_s == ent.name }
            unless list_attrs.empty?
              tables << generate_entity_table(ent, agg)
            end
          end
        end

        tables.join("\n\n")
      end

      def generate_aggregate_table(agg)
        lines = []
        lines << "CREATE TABLE #{table_name(agg.name)} ("
        lines << "  id VARCHAR(36) PRIMARY KEY"

        agg.attributes.each do |attr|
          next if attr.list?
          lines << "  #{attr.name} #{sql_type(attr)},"
        end

        # Fix trailing comma on last line before id
        lines[1] = lines[1] + "," if agg.attributes.any? { |a| !a.list? }

        # Remove trailing comma from last attribute
        lines[-1] = lines[-1].chomp(",")

        lines << ");"
        lines.join("\n")
      end

      def generate_value_object_table(vo, parent_agg)
        parent_table = table_name(parent_agg.name)
        vo_table = "#{parent_table}_#{table_name(vo.name)}"

        lines = []
        lines << "CREATE TABLE #{vo_table} ("
        lines << "  id VARCHAR(36) PRIMARY KEY,"
        lines << "  #{Hecks::Utils.underscore(Hecks::Utils.sanitize_constant(parent_agg.name))}_id VARCHAR(36) NOT NULL REFERENCES #{parent_table}(id),"

        vo.attributes.each_with_index do |attr, i|
          comma = i < vo.attributes.size - 1 ? "," : ""
          lines << "  #{attr.name} #{sql_type(attr)}#{comma}"
        end

        lines << ");"
        lines.join("\n")
      end

      def generate_entity_table(ent, parent_agg)
        parent_table = table_name(parent_agg.name)
        ent_table = "#{parent_table}_#{table_name(ent.name)}"

        lines = []
        lines << "CREATE TABLE #{ent_table} ("
        lines << "  id VARCHAR(36) PRIMARY KEY,"
        lines << "  #{Hecks::Utils.underscore(Hecks::Utils.sanitize_constant(parent_agg.name))}_id VARCHAR(36) NOT NULL REFERENCES #{parent_table}(id),"

        ent.attributes.each_with_index do |attr, i|
          comma = i < ent.attributes.size - 1 ? "," : ""
          lines << "  #{attr.name} #{sql_type(attr)}#{comma}"
        end

        lines << ");"
        lines.join("\n")
      end

      private

      def sql_type(attr)
        return "VARCHAR(36)" if attr.reference?

        case attr.type.to_s
        when "String"  then "VARCHAR(255)"
        when "Integer" then "INTEGER"
        when "Float"   then "REAL"
        when "Boolean", "TrueClass", "FalseClass" then "BOOLEAN"
        else "TEXT"
        end
      end

      def table_name(name)
        Hecks::Utils.underscore(Hecks::Utils.sanitize_constant(name)) + "s"
      end
    end
    end
  end
end
