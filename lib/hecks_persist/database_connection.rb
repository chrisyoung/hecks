# Hecks::Configuration::DatabaseConnection
#
# Connects to databases via Sequel. Supports MySQL, Postgres, SQLite,
# connection URLs, and auto-detection from Rails database config.
#
#   adapter :sql, database: :mysql, host: "localhost", name: "pizzas"
#   adapter :sql, url: "postgres://user:pass@host/db"
#   adapter :sql  # defaults to SQLite in-memory
#
module Hecks
  class Configuration
    module DatabaseConnection
      private

      def connect_database
        require "sequel"

        if @adapter_options[:url]
          Sequel.connect(@adapter_options[:url])
        elsif @adapter_options[:database]
          connect_by_type(@adapter_options)
        elsif defined?(::Rails)
          connect_from_rails
        else
          Sequel.sqlite
        end
      end

      def connect_by_type(opts)
        case opts[:database]
        when :mysql
          Sequel.connect(adapter: :mysql2, host: opts[:host] || "localhost",
            user: opts[:user] || "root", password: opts[:password], database: opts[:name])
        when :postgres
          Sequel.connect(adapter: :postgres, host: opts[:host] || "localhost",
            user: opts[:user], password: opts[:password], database: opts[:name])
        when :sqlite
          Sequel.sqlite(opts[:name])
        else
          raise "Unknown database type: #{opts[:database]}. Use :sqlite, :mysql, or :postgres."
        end
      end

      def connect_from_rails
        db_config = ActiveRecord::Base.connection_db_config
        url = db_config.try(:url) || db_config.configuration_hash[:url]
        url ? Sequel.connect(url) : Sequel.sqlite
      end
    end
  end
end
