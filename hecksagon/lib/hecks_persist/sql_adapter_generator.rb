require_relative "sql_builder"

module Hecks
  module Generators
    module SQL
    # Hecks::Generators::SQL::SqlAdapterGenerator
    #
    # Generates SQL-backed repository implementations using Sequel datasets.
    # Supports any database Sequel connects to (SQLite, MySQL, Postgres).
    # Handles join tables for list-type value objects. Part of Generators::SQL,
    # consumed by DomainGemGenerator for SQL persistence.
    #
    #   gen = SqlAdapterGenerator.new(agg, domain_module: "PizzasDomain")
    #   gen.generate  # => "module PizzasDomain\n  module Adapters\n  ..."
    #
    class SqlAdapterGenerator
      include HecksTemplating::NamingHelpers
      include SqlBuilder

      # Initializes a generator for a single aggregate's SQL repository.
      #
      # @param aggregate [DomainModel::Structure::Aggregate] the aggregate to
      #   generate a repository for
      # @param domain_module [String] the fully qualified module name
      #   (e.g., "PizzasDomain")
      # @param searchable_fields [Array<String>] field names tagged :searchable
      def initialize(aggregate, domain_module:, searchable_fields: [])
        @aggregate = aggregate
        @domain_module = domain_module
        @searchable_fields = searchable_fields
      end

      # Generates the full SQL repository class source code.
      #
      # Produces a class that implements the aggregate's repository port with
      # Sequel-based CRUD operations: find, save (insert/update), delete, all,
      # count, and query (with operator support for Gt, Lt, etc.). Includes
      # private insert, update, and build methods. Handles join tables for
      # list-type value objects.
      #
      # @return [String] the complete Ruby source code for the repository class
      def generate
        lines = []
        lines << "require \"time\""
        lines << "require \"json\"" if has_json_attributes?
        lines << ""
        lines << "module #{@domain_module}"
        lines << "  module Adapters"
        safe_name = domain_constant_name(@aggregate.name)
        lines << "    class #{safe_name}SqlRepository"
        lines << "      include Ports::#{safe_name}Repository"
        lines << ""
        lines << "      def initialize(db)"
        lines << "        @db = db"
        lines << "      end"
        lines << ""
        lines << "      def find(id)"
        lines << "        row = @db[:#{table_name}].where(id: id).first"
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
        lines << "        @db[:#{table_name}].where(id: id).delete"
        lines << "      end"
        lines << ""
        lines << "      def all"
        lines << "        @db[:#{table_name}].all.map { |row| build(row) }"
        lines << "      end"
        lines << ""
        lines << "      def count"
        lines << "        @db[:#{table_name}].count"
        lines << "      end"
        lines << ""
        lines << "      def query(conditions: {}, order_key: nil, order_direction: :asc, limit: nil, offset: nil)"
        lines << "        ds = @db[:#{table_name}]"
        lines << "        unless conditions.empty?"
        lines << "          conditions.each do |k, v|"
        lines << "            ds = v.is_a?(Hecks::Querying::Operators::Operator) ? ds.where(sequel_op(k, v)) : ds.where(k => v)"
        lines << "          end"
        lines << "        end"
        lines << "        ds = ds.order(order_direction == :desc ? Sequel.desc(order_key) : order_key) if order_key"
        lines << "        ds = ds.limit(limit) if limit"
        lines << "        ds = ds.offset(offset) if offset"
        lines << "        ds.all.map { |row| build(row) }"
        lines << "      end"
        lines << ""
        lines.concat(search_lines)
        lines << "      private"
        lines << ""
        lines << "      def sequel_op(col, op)"
        lines << "        v = op.value"
        lines << "        sym = op.respond_to?(:sequel_op) ? op.sequel_op : :=="
        lines << "        case sym"
        lines << "        when :!=  then Sequel.negate(col => v)"
        lines << "        when :in  then Sequel.expr(col => v)"
        lines << "        else Sequel.expr(col).send(sym, v)"
        lines << "        end"
        lines << "      end"
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

      # Generates a search(term) method when searchable fields are configured.
      #
      # Uses Sequel.ilike (case-insensitive LIKE) across all searchable fields,
      # joined with OR. Returns an empty array when no searchable fields are declared.
      # Works with SQLite, Postgres, and MySQL — no tsvector required.
      #
      # @return [Array<String>] lines of Ruby source code for the search method
      def search_lines
        return [] if @searchable_fields.empty?

        fields = @searchable_fields
        lines = []
        lines << "      def search(term)"
        lines << "        ds = @db[:#{table_name}]"
        if fields.length == 1
          lines << "        ds = ds.where(Sequel.ilike(:#{fields.first}, \"%\#{term}%\"))"
        else
          like_parts = fields.map { |f| "Sequel.ilike(:#{f}, \"%\#{term}%\")" }.join(", ")
          lines << "        ds = ds.where(Sequel.|(" + like_parts + "))"
        end
        lines << "        ds.all.map { |row| build(row) }"
        lines << "      end"
        lines << ""
        lines
      end

      # Returns the SQL table name for the aggregate (underscore + pluralized).
      #
      # @return [String] the table name (e.g., "pizzas")
      def table_name
        domain_aggregate_slug(@aggregate.name)
      end

      # Returns the snake_case name for the aggregate (used in variable names).
      #
      # @return [String] the snake_case name (e.g., "pizza")
      def snake_name
        domain_snake_name(domain_constant_name(@aggregate.name))
      end

      # Returns attributes that are stored as direct columns (not list types).
      #
      # @return [Array<DomainModel::Structure::Attribute>] scalar attributes
      def scalar_attributes
        @aggregate.attributes.reject(&:list?)
      end

      # Checks if any attributes use JSON serialization.
      #
      # @return [Boolean] true if any attribute is JSON-typed
      def has_json_attributes?
        @aggregate.attributes.any?(&:json?)
      end

      # Returns value objects that are stored in join tables (list-type VOs).
      #
      # @return [Array<DomainModel::Structure::ValueObject>] list value objects
      def list_value_objects
        @aggregate.value_objects.select do |vo|
          @aggregate.attributes.any? { |a| a.list? && a.type.to_s == vo.name }
        end
      end
    end
    end
  end
end
