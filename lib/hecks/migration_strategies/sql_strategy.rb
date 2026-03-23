# Hecks::MigrationStrategies::SqlStrategy
#
# Generates SQL migration files from domain changes. Produces ALTER TABLE
# statements for attribute changes and CREATE TABLE for new aggregates.
# Output goes to db/hecks_migrate/ to avoid conflicts with ActiveRecord.
#
# Registered as :sql — used by `hecks generate:migrations` and the
# Rails generator `rails generate active_hecks:migration`.
#
#   strategy = SqlStrategy.new(output_dir: ".")
#   strategy.generate(changes)
#   # => "ALTER TABLE pizzas ADD COLUMN size VARCHAR(255);\n..."
#
require "fileutils"

module Hecks
  module MigrationStrategies
    class SqlStrategy < MigrationStrategy
      def generate(changes)
        lines = []

        changes.each do |change|
          case change.kind
          when :add_aggregate
            lines << generate_create_table(change)
          when :remove_aggregate
            lines << "DROP TABLE IF EXISTS #{table_name(change.aggregate)};"
          when :add_attribute
            lines << generate_add_column(change)
          when :remove_attribute
            lines << "ALTER TABLE #{table_name(change.aggregate)} DROP COLUMN #{change.details[:name]};"
          when :add_value_object
            lines << generate_create_join_table(change)
          when :remove_value_object
            lines << "DROP TABLE IF EXISTS #{join_table_name(change.aggregate, change.details[:name])};"
          end
        end

        return nil if lines.empty?
        lines.compact.join("\n\n") + "\n"
      end

      def file_path
        timestamp = Time.now.strftime("%Y%m%d%H%M%S")
        "db/hecks_migrate/#{timestamp}_hecks_migration.sql"
      end

      private

      def generate_create_table(change)
        tables = []

        cols = ["  id VARCHAR(36) PRIMARY KEY"]
        change.details[:attributes].each do |attr|
          next if attr.list?
          cols << "  #{attr.name} #{sql_type(attr)}"
        end
        cols << "  created_at DATETIME"
        cols << "  updated_at DATETIME"
        tables << "CREATE TABLE #{table_name(change.aggregate)} (\n#{cols.join(",\n")}\n);"

        # Generate join tables for list value objects
        (change.details[:value_objects] || []).each do |vo|
          list_attr = change.details[:attributes].find { |a| a.list? && a.type.to_s == vo.name }
          next unless list_attr
          tables << generate_create_join_table_from_vo(change.aggregate, vo)
        end

        tables.join("\n\n")
      end

      def generate_create_join_table_from_vo(aggregate_name, vo)
        parent_table = table_name(aggregate_name)
        jt = join_table_name(aggregate_name, vo.name)
        parent_fk = "#{Hecks::Utils.underscore(aggregate_name)}_id"

        cols = [
          "  id VARCHAR(36) PRIMARY KEY",
          "  #{parent_fk} VARCHAR(36) NOT NULL REFERENCES #{parent_table}(id)"
        ]
        vo.attributes.each do |attr|
          cols << "  #{attr.name} #{sql_type(attr)}"
        end

        "CREATE TABLE #{jt} (\n#{cols.join(",\n")}\n);"
      end

      def generate_add_column(change)
        d = change.details
        return nil if d[:list]

        type = if d[:reference]
                 "VARCHAR(36)"
               else
                 sql_type_for(d[:type])
               end

        "ALTER TABLE #{table_name(change.aggregate)} ADD COLUMN #{d[:name]} #{type};"
      end

      def generate_create_join_table(change)
        parent_table = table_name(change.aggregate)
        vo_name = change.details[:name]
        jt = join_table_name(change.aggregate, vo_name)
        parent_fk = "#{Hecks::Utils.underscore(change.aggregate)}_id"

        cols = [
          "  id VARCHAR(36) PRIMARY KEY",
          "  #{parent_fk} VARCHAR(36) NOT NULL REFERENCES #{parent_table}(id)"
        ]
        change.details[:attributes].each do |attr|
          cols << "  #{attr.name} #{sql_type(attr)}"
        end

        "CREATE TABLE #{jt} (\n#{cols.join(",\n")}\n);"
      end

      def table_name(aggregate_name)
        Hecks::Utils.underscore(aggregate_name) + "s"
      end

      def join_table_name(aggregate_name, vo_name)
        "#{table_name(aggregate_name)}_#{Hecks::Utils.underscore(vo_name)}s"
      end

      def sql_type(attr)
        return "VARCHAR(36)" if attr.reference?
        sql_type_for(attr.type)
      end

      def sql_type_for(type)
        case type.to_s
        when "String"  then "VARCHAR(255)"
        when "Integer" then "INTEGER"
        when "Float"   then "REAL"
        when "Boolean", "TrueClass", "FalseClass" then "BOOLEAN"
        else "TEXT"
        end
      end
    end
  end
end
