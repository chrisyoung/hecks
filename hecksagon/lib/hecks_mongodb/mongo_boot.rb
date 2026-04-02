# = Hecks::Boot::MongoBoot
#
# Handles MongoDB adapter lifecycle: connects to a MongoDB instance,
# generates repository adapter classes for each aggregate, and returns
# adapter instances keyed by aggregate name. When a hecksagon is provided,
# creates { attr => 1 } indexes for attributes tagged :indexed.
#
#   adapters = MongoBoot.setup(domain, client)
#   # => { "Pizza" => #<PizzasDomain::Adapters::PizzaMongoRepository>, ... }
#
#   adapters = MongoBoot.setup(domain, client, hecksagon: hex)
#   # => also creates indexes for :indexed attributes
#
module Hecks
  module Boot
    module MongoBoot
      extend HecksTemplating::NamingHelpers

      module_function

      # Connects to MongoDB using the mongo Ruby driver.
      #
      # @param config [Hash] connection config with :uri or defaults
      # @return [Mongo::Client] the MongoDB client
      def connect(config)
        require_mongo!
        uri = config[:uri] || "mongodb://localhost:27017"
        db_name = config[:database] || "hecks"
        Mongo::Client.new(uri, database: db_name)
      end

      # Performs full MongoDB setup: generates adapter classes, creates indexes,
      # and returns instantiated repository objects.
      #
      # @param domain [DomainModel::Structure::Domain] the domain model
      # @param client [Mongo::Client] the MongoDB client
      # @param hecksagon [Hecksagon::Structure::Hecksagon, nil] optional hecksagon for capability tags
      # @return [Hash<String, Object>] adapter instances keyed by aggregate name
      def setup(domain, client, hecksagon: nil)
        mod_name = domain_module_name(domain.name)
        generate_adapters(domain, mod_name, hecksagon: hecksagon)
        adapters = instantiate_adapters(domain, client, mod_name)
        if hecksagon
          create_indexes(domain, client, hecksagon)
          create_text_indexes(domain, client, hecksagon)
        end
        adapters
      end

      # Generates and evals MongoDB repository classes for each aggregate.
      #
      # @param domain [DomainModel::Structure::Domain] the domain model
      # @param mod_name [String] the domain module name (e.g., "PizzasDomain")
      # @param hecksagon [Hecksagon::Structure::Hecksagon, nil] optional hecksagon IR
      def generate_adapters(domain, mod_name, hecksagon: nil)
        domain.aggregates.each do |agg|
          fields = hecksagon ? hecksagon.searchable_fields(agg.name) : []
          gen = MongoAdapterGenerator.new(agg, domain_module: mod_name, searchable_fields: fields)
          eval(gen.generate, TOPLEVEL_BINDING, "(mongo_adapter:#{agg.name})", 1)
        end
      end

      # Instantiates MongoDB repository objects for all aggregates.
      def instantiate_adapters(domain, client, mod_name)
        mod = Object.const_get(mod_name)
        adapters = {}
        domain.aggregates.each do |agg|
          safe_name = domain_constant_name(agg.name)
          collection_name = domain_aggregate_slug(agg.name)
          collection = client[collection_name]
          repo_class = mod::Adapters.const_get("#{safe_name}MongoRepository")
          adapters[agg.name] = repo_class.new(collection)
        end
        adapters
      end

      # Creates MongoDB indexes for attributes tagged :indexed in the hecksagon.
      #
      # @param domain [DomainModel::Structure::Domain] the domain model
      # @param client [Mongo::Client] the MongoDB client
      # @param hecksagon [Hecksagon::Structure::Hecksagon] the hecksagon IR
      # @return [void]
      def create_indexes(domain, client, hecksagon)
        domain.aggregates.each do |agg|
          indexed = hecksagon.indexed_attributes_for(agg.name)
          next if indexed.empty?
          collection = client[domain_aggregate_slug(agg.name)]
          indexed.each do |attr|
            collection.indexes.create_one({ attr => 1 })
          end
        end
      end

      # Creates MongoDB text indexes for aggregates with :searchable fields.
      #
      # Each collection receives a compound text index covering all searchable
      # fields, enabling $text search queries via the generated search(term) method.
      #
      # @param domain [DomainModel::Structure::Domain] the domain model
      # @param client [Mongo::Client] the MongoDB client
      # @param hecksagon [Hecksagon::Structure::Hecksagon] the hecksagon IR
      # @return [void]
      def create_text_indexes(domain, client, hecksagon)
        domain.aggregates.each do |agg|
          fields = hecksagon.searchable_fields(agg.name)
          next if fields.empty?

          collection = client[domain_aggregate_slug(agg.name)]
          index_spec = fields.each_with_object({}) { |f, h| h[f] = "text" }
          collection.indexes.create_one(index_spec)
        end
      end

      # Requires the mongo gem, raising a helpful error if missing.
      def require_mongo!
        require "mongo"
      rescue LoadError
        raise LoadError,
          "The mongo gem is required for MongoDB adapters. " \
          "Add gem \"mongo\" to your Gemfile."
      end
    end
  end
end
