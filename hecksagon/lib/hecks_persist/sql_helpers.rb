
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
        include HecksTemplating::NamingHelpers
        # Computes the SQL table name for an aggregate (underscore + pluralized).
        #
        # @param aggregate_name [String] the aggregate name (e.g., "Pizza")
        # @return [String] the table name (e.g., "pizzas")
        def table_name(aggregate_name)
          domain_aggregate_slug(aggregate_name)
        end

        # Computes the join table name for a value object on an aggregate.
        #
        # @param aggregate_name [String] the parent aggregate name
        # @param vo_name [String] the value object name
        # @return [String] the join table name (e.g., "pizzas_toppings")
        def join_table_name(aggregate_name, vo_name)
          "#{table_name(aggregate_name)}_#{domain_snake_name(vo_name)}s"
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
        # @param attr [DomainModel::Structure::Attribute] the attribute
        # @return [String] the SQL type (e.g., "VARCHAR(255)", "INTEGER")
        def sql_type(attr)
          sql_type_for(attr.type)
        end

        # Returns the SQL column name for a reference (role_id).
        #
        # @param ref [DomainModel::Structure::Reference] the reference
        # @return [String] the column name (e.g., "team_id")
        def reference_column_name(ref)
          "#{ref.name}_id"
        end

        # Maps a Ruby type name to its SQL column type.
        #
        # @param type [String, Class] the type name or class
        # @return [String] the SQL type string
        def sql_type_for(type)
          t = type.to_s
          # Handle Ruby's boolean class names
          t = "Boolean" if %w[TrueClass FalseClass].include?(t)
          HecksTemplating::TypeContract.sql(t)
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

        # Generates a search index SQL statement for the given table and fields.
        #
        # For Postgres: creates a GIN index on a tsvector expression so full-text
        # search can use an index scan. For all other adapters (SQLite, MySQL):
        # generates nothing (LIKE-based search is done at query time without a
        # dedicated index object).
        #
        # @param table [String] the SQL table name (e.g., "pizzas")
        # @param fields [Array<String>] column names to include in the search index
        # @param adapter_type [Symbol] :postgres, :sqlite, :mysql, etc.
        # @return [String, nil] the CREATE INDEX SQL string, or nil for non-Postgres
        def searchable_index_sql(table, fields, adapter_type: :sqlite)
          return nil if fields.empty?
          return nil unless adapter_type == :postgres

          idx_name = "idx_#{table}_fts"
          tsvector = fields.map { |f| "coalesce(#{f}::text, '')" }.join(" || ' ' || ")
          "CREATE INDEX #{idx_name} ON #{table} USING gin(to_tsvector('english', #{tsvector}));"
        end

        # Generates CREATE INDEX statements for reference FK columns plus any
        # attributes tagged :indexed in the hecksagon for an :add_aggregate change.
        #
        # @param change [Migrations::Change] the :add_aggregate change
        # @param hecksagon [Hecksagon::Structure::Hecksagon, nil] optional hecksagon IR
        # @return [String, nil] CREATE INDEX SQL, or nil if no indexes needed
        def build_table_indexes(change, hecksagon = nil)
          agg_name = change.aggregate
          stmts = []
          (change.details[:references] || []).each do |ref|
            col = reference_column_name(ref)
            stmts << "CREATE INDEX #{index_name(agg_name, [col])} ON #{table_name(agg_name)}(#{col});"
          end
          if hecksagon
            hecksagon.indexed_attributes_for(agg_name).each do |col|
              stmts << "CREATE INDEX #{index_name(agg_name, [col])} ON #{table_name(agg_name)}(#{col});"
            end
          end
          stmts.empty? ? nil : stmts.join("\n")
        end

        # Generates a CREATE INDEX for an :add_attribute change when the attribute
        # is tagged :indexed in the hecksagon.
        #
        # @param change [Migrations::Change] the :add_attribute change
        # @param hecksagon [Hecksagon::Structure::Hecksagon, nil] optional hecksagon IR
        # @return [String, nil] CREATE INDEX SQL, or nil if not indexed
        def build_attribute_index(change, hecksagon = nil)
          return nil unless hecksagon
          d = change.details
          return nil if d[:list]
          col = d[:name].to_s
          return nil unless hecksagon.indexed_attributes_for(change.aggregate).include?(col)
          tbl = table_name(change.aggregate)
          "CREATE INDEX #{index_name(change.aggregate, [col])} ON #{tbl}(#{col});"
        end
      end
    end
  end
end
