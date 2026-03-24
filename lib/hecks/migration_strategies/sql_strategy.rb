# Hecks::Migrations::Strategies::SqlStrategy
#
# Generates SQL migration files from domain changes. Produces ALTER TABLE
# statements for attribute changes and CREATE TABLE for new aggregates.
# Supports NOT NULL (from presence validations), UNIQUE (from uniqueness
# validations), DEFAULT values, foreign key cascading, and indexes.
# Output goes to db/hecks_migrate/ to avoid conflicts with ActiveRecord.
#
#   strategy = SqlStrategy.new(output_dir: ".")
#   strategy.generate(changes)
#
require "fileutils"
require_relative "sql_helpers"

module Hecks
  module Migrations
    module Strategies
      class SqlStrategy < MigrationStrategy
      include SqlHelpers
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
          when :add_index
            lines << generate_add_index(change)
          when :remove_index
            lines << generate_drop_index(change)
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
        presence_fields = presence_fields_from(change.details[:validations])
        unique_fields = unique_fields_from(change.details[:validations])

        cols = ["  id VARCHAR(36) PRIMARY KEY"]
        change.details[:attributes].each do |attr|
          next if attr.list?
          cols << "  #{column_def(attr, presence_fields, unique_fields)}"
        end
        cols << "  created_at DATETIME"
        cols << "  updated_at DATETIME"
        tables << "CREATE TABLE #{table_name(change.aggregate)} (\n#{cols.join(",\n")}\n);"

        # Generate indexes
        indexes_sql = generate_indexes_for_table(change)
        tables << indexes_sql if indexes_sql

        # Generate join tables for list value objects
        (change.details[:value_objects] || []).each do |vo|
          list_attr = change.details[:attributes].find { |a| a.list? && a.type.to_s == vo.name }
          next unless list_attr
          tables << generate_create_join_table_from_vo(change.aggregate, vo)
        end

        tables.compact.join("\n\n")
      end

      def column_def(attr, presence_fields = [], unique_fields = [])
        parts = [attr.name.to_s, sql_type(attr)]
        if attr.reference?
          ref_table = Hecks::Utils.underscore(attr.type.to_s.sub(/_id$/, "")) + "s"
          parts << "REFERENCES #{ref_table}(id) ON DELETE SET NULL"
        end
        parts << "NOT NULL" if presence_fields.include?(attr.name.to_sym)
        parts << "UNIQUE" if unique_fields.include?(attr.name.to_sym)
        parts << "DEFAULT #{sql_literal(attr.default)}" unless attr.default.nil?
        parts.join(" ")
      end

      def generate_create_join_table_from_vo(aggregate_name, vo)
        parent_table = table_name(aggregate_name)
        jt = join_table_name(aggregate_name, vo.name)
        parent_fk = "#{Hecks::Utils.underscore(aggregate_name)}_id"

        cols = [
          "  id VARCHAR(36) PRIMARY KEY",
          "  #{parent_fk} VARCHAR(36) NOT NULL REFERENCES #{parent_table}(id) ON DELETE CASCADE"
        ]
        vo.attributes.each do |attr|
          cols << "  #{attr.name} #{sql_type(attr)}"
        end

        "CREATE TABLE #{jt} (\n#{cols.join(",\n")}\n);"
      end

      def generate_add_column(change)
        d = change.details
        return nil if d[:list]

        type = d[:reference] ? "VARCHAR(36)" : sql_type_for(d[:type])
        parts = ["#{d[:name]} #{type}"]
        if d[:reference]
          ref_table = Hecks::Utils.underscore(d[:type].to_s.sub(/_id$/, "")) + "s"
          parts << "REFERENCES #{ref_table}(id) ON DELETE SET NULL"
        end
        parts << "NOT NULL" if d[:presence]
        parts << "UNIQUE" if d[:uniqueness]
        parts << "DEFAULT #{sql_literal(d[:default])}" if d[:default]

        "ALTER TABLE #{table_name(change.aggregate)} ADD COLUMN #{parts.join(" ")};"
      end

      def generate_create_join_table(change)
        parent_table = table_name(change.aggregate)
        vo_name = change.details[:name]
        jt = join_table_name(change.aggregate, vo_name)
        parent_fk = "#{Hecks::Utils.underscore(change.aggregate)}_id"

        cols = [
          "  id VARCHAR(36) PRIMARY KEY",
          "  #{parent_fk} VARCHAR(36) NOT NULL REFERENCES #{parent_table}(id) ON DELETE CASCADE"
        ]
        change.details[:attributes].each do |attr|
          cols << "  #{attr.name} #{sql_type(attr)}"
        end

        "CREATE TABLE #{jt} (\n#{cols.join(",\n")}\n);"
      end

      def generate_add_index(change)
        idx_name = index_name(change.aggregate, change.details[:fields])
        unique = change.details[:unique] ? "UNIQUE " : ""
        cols = change.details[:fields].join(", ")
        "CREATE #{unique}INDEX #{idx_name} ON #{table_name(change.aggregate)}(#{cols});"
      end

      def generate_drop_index(change)
        idx_name = index_name(change.aggregate, change.details[:fields])
        "DROP INDEX IF EXISTS #{idx_name};"
      end

      def generate_indexes_for_table(change)
        return nil unless change.details[:attributes]
        agg_name = change.aggregate
        # Auto-index reference columns
        ref_attrs = change.details[:attributes].select(&:reference?)
        return nil if ref_attrs.empty?
        ref_attrs.map do |attr|
          idx = index_name(agg_name, [attr.name])
          "CREATE INDEX #{idx} ON #{table_name(agg_name)}(#{attr.name});"
        end.join("\n")
      end

      end
    end
  end
end
