# Hecks::Migrations::Strategies::SqlHelpers
#
# Shared helpers for SQL migration generation: type mapping, naming
# conventions, literal quoting, and validation extraction. Mixed into
# SqlStrategy to keep it under the 200-line limit.
#
module Hecks
  module Migrations
    module Strategies
      module SqlHelpers
        def table_name(aggregate_name)
          Hecks::Utils.underscore(aggregate_name) + "s"
        end

        def join_table_name(aggregate_name, vo_name)
          "#{table_name(aggregate_name)}_#{Hecks::Utils.underscore(vo_name)}s"
        end

        def index_name(aggregate_name, fields)
          "idx_#{table_name(aggregate_name)}_#{fields.join("_")}"
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
          when "Date"     then "DATE"
          when "DateTime" then "VARCHAR(255)"
          else "TEXT"
          end
        end

        def sql_literal(value)
          case value
          when String then "'#{value}'"
          when true   then "TRUE"
          when false  then "FALSE"
          when nil    then "NULL"
          else value.to_s
          end
        end

        def presence_fields_from(validations)
          (validations || []).select(&:presence?).map(&:field)
        end

        def unique_fields_from(validations)
          (validations || []).select(&:uniqueness?).map(&:field)
        end
      end
    end
  end
end
