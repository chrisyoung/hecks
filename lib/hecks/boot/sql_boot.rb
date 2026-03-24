# Hecks::Boot::SqlBoot
#
# Handles SQL adapter lifecycle: connects to a database via Sequel,
# generates SQL repository classes for each aggregate, creates tables
# from the domain IR, and returns adapter instances keyed by aggregate name.
# Part of Boot, consumed by Hecks.boot when adapter: :sqlite (or similar).
#
#   adapters = SqlBoot.setup(domain, db)
#   # => { "Pizza" => #<PizzasDomain::Adapters::PizzaSqlRepository>, ... }
#
module Hecks
  module Boot
    module SqlBoot
      # Map domain type names to Sequel column types.
      TYPE_MAP = {
        "String"  => String,
        "Integer" => Integer,
        "Float"   => Float,
        "Boolean" => :boolean,
        "JSON"    => String
      }.freeze

      module_function

      # Connect to the database based on adapter config.
      #
      # @param adapter [Symbol, Hash] :sqlite or { type: :sqlite, database: "path.db" }
      # @return [Sequel::Database]
      def connect(adapter)
        require_sequel!
        config = normalize_config(adapter)

        case config[:type]
        when :sqlite
          config[:database] ? Sequel.sqlite(config[:database]) : Sequel.sqlite
        when :postgres
          Sequel.connect(config)
        when :mysql, :mysql2
          Sequel.connect(config)
        else
          raise ArgumentError, "Unknown SQL adapter type: #{config[:type]}"
        end
      end

      # Full SQL setup: generate adapter classes, create tables, return repo map.
      #
      # @param domain [DomainModel::Structure::Domain]
      # @param db [Sequel::Database]
      # @return [Hash<String, Object>] adapter instances keyed by aggregate name
      def setup(domain, db)
        mod_name = domain.module_name + "Domain"
        generate_adapters(domain, mod_name)
        create_tables(domain, db)
        instantiate_adapters(domain, db, mod_name)
      end

      # Generate and eval SQL repository classes for each aggregate.
      def generate_adapters(domain, mod_name)
        domain.aggregates.each do |agg|
          gen = Generators::SQL::SqlAdapterGenerator.new(agg, domain_module: mod_name)
          eval(gen.generate, TOPLEVEL_BINDING, "(sql_adapter:#{agg.name})", 1)
        end
      end

      # Create tables for all aggregates (idempotent -- skips existing tables).
      def create_tables(domain, db)
        domain.aggregates.each do |agg|
          create_aggregate_table(agg, db)
          create_vo_join_tables(agg, db)
        end
      end

      # Instantiate SQL repository objects keyed by aggregate name.
      def instantiate_adapters(domain, db, mod_name)
        mod = Object.const_get(mod_name)
        adapters = {}
        domain.aggregates.each do |agg|
          safe_name = Utils.sanitize_constant(agg.name)
          repo_class = mod::Adapters.const_get("#{safe_name}SqlRepository")
          adapters[agg.name] = repo_class.new(db)
        end
        adapters
      end

      # Create the main table for an aggregate from its IR attributes.
      def create_aggregate_table(agg, db)
        tbl = table_name_for(agg)
        return if db.table_exists?(tbl)

        cols = agg.attributes.reject(&:list?).map { |a| [a.name, sequel_type(a)] }
        db.create_table(tbl) do
          String :id, primary_key: true, size: 36
          cols.each { |name, type| column name, type }
          String :created_at
          String :updated_at
        end
      end

      # Create join tables for list-type value objects.
      def create_vo_join_tables(agg, db)
        agg_table = table_name_for(agg)
        agg_snake = Utils.underscore(Utils.sanitize_constant(agg.name))

        list_vos(agg).each do |vo, _list_attr|
          vo_table = :"#{agg_table}_#{Utils.underscore(vo.name)}s"
          next if db.table_exists?(vo_table)

          fk_name = :"#{agg_snake}_id"
          vo_cols = vo.attributes.map { |a| [a.name, sequel_type(a)] }
          db.create_table(vo_table) do
            String :id, primary_key: true, size: 36
            String fk_name, null: false
            vo_cols.each { |name, type| column name, type }
          end
        end
      end

      # Pairs of [value_object, list_attribute] for list-type VOs on an aggregate.
      def list_vos(agg)
        agg.value_objects.filter_map do |vo|
          list_attr = agg.attributes.find { |a| a.list? && a.type.to_s == vo.name }
          [vo, list_attr] if list_attr
        end
      end

      # Table name for an aggregate: underscore + pluralize.
      def table_name_for(agg)
        (Utils.underscore(Utils.sanitize_constant(agg.name)) + "s").to_sym
      end

      # Map a domain attribute to a Sequel column type.
      def sequel_type(attr)
        return String if attr.reference?
        TYPE_MAP.fetch(attr.type.to_s, String)
      end

      def normalize_config(adapter)
        case adapter
        when Symbol then { type: adapter }
        when Hash   then adapter
        else raise ArgumentError, "adapter must be a Symbol or Hash, got #{adapter.class}"
        end
      end

      def require_sequel!
        require "sequel"
      rescue LoadError
        raise LoadError,
          "The sequel gem is required for SQL adapters. " \
          "Add gem \"sequel\" and gem \"sqlite3\" (or your DB driver) to your Gemfile."
      end
    end
  end
end
