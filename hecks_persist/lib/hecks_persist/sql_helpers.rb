module Hecks
  module Migrations
    module Strategies
      # Hecks::Migrations::Strategies::SqlHelpers
      #
      # Shared helpers for SQL migration generation: type mapping, naming
      # conventions, literal quoting, and validation extraction. Mixed into
      # SqlStrategy to keep it under the 200-line limit.
      #
      module SqlHelpers
        # Computes the SQL table name for an aggregate (underscore + pluralized).
        #
        # @param aggregate_name [String] the aggregate name (e.g., "Pizza")
        # @return [String] the table name (e.g., "pizzas")
        def table_name(aggregate_name)
          Hecks::Templating::Names.table_name(aggregate_name)
        end

        # Computes the join table name for a value object on an aggregate.
        #
        # @param aggregate_name [String] the parent aggregate name
        # @param vo_name [String] the value object name
        # @return [String] the join table name (e.g., "pizzas_toppings")
        def join_table_name(aggregate_name, vo_name)
          "#{table_name(aggregate_name)}_#{Hecks::Utils.underscore(vo_name)}s"
        end

        # Computes an index name from aggregate and field names.
        #
        # @param aggregate_name [String] the aggregate name
        # @param fields [Array<String, Symbol>] the indexed field names
        # @return [String] the index name (e.g., "idx_pizzas_size_flavor")
        def index_name(aggregate_name, fields)
          "idx_#{table_name(aggregate_name)}_#{fields.join("_")}"
        end

        # Maps a domain attribute to its SQL column type.
        #
        # Reference attributes are mapped to VARCHAR(36) for UUID foreign keys.
        # Other types are mapped via sql_type_for.
        #
        # @param attr [DomainModel::Structure::Attribute] the attribute
        # @return [String] the SQL type (e.g., "VARCHAR(255)", "INTEGER")
        def sql_type(attr)
          return "VARCHAR(36)" if attr.reference?
          sql_type_for(attr.type)
        end

        # Maps a Ruby type name to its SQL column type.
        #
        # @param type [String, Class] the type name or class
        # @return [String] the SQL type string
        def sql_type_for(type)
          t = type.to_s
          # Handle Ruby's boolean class names
          t = "Boolean" if %w[TrueClass FalseClass].include?(t)
          Hecks::TypeContract.sql(t)
        end

        # Converts a Ruby value to a SQL literal string.
        #
        # @param value [String, Boolean, nil, Numeric] the value to convert
        # @return [String] the SQL literal (e.g., "'hello'", "TRUE", "NULL")
        def sql_literal(value)
          case value
          when String then "'#{value}'"
          when true   then "TRUE"
          when false  then "FALSE"
          when nil    then "NULL"
          else value.to_s
          end
        end

        # Extracts field names from presence validations.
        #
        # @param validations [Array<Validation>, nil] the validation list
        # @return [Array<Symbol>] field names with presence validations
        def presence_fields_from(validations)
          (validations || []).select(&:presence?).map(&:field)
        end

        # Extracts field names from uniqueness validations.
        #
        # @param validations [Array<Validation>, nil] the validation list
        # @return [Array<Symbol>] field names with uniqueness validations
        def unique_fields_from(validations)
          (validations || []).select(&:uniqueness?).map(&:field)
        end
      end
    end
  end
end
