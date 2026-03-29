
# Hecks::CLI::Domain#generate_sinatra
#
# Scaffolds a Sinatra web app from a domain definition. Generates a Gemfile,
# config.ru, app.rb with CRUD + query routes, and a Hecks config file.
# CLI command layer; invoked via `hecks domain generate:sinatra`.
#
#   hecks domain generate:sinatra [--domain NAME] [--dir OUTPUT]
#
module Hecks
  class CLI < Thor
    class Domain < Thor
      include Hecks::NamingHelpers
      desc "generate:sinatra", "Scaffold a Sinatra app from a domain"
      map "generate:sinatra" => :generate_sinatra
      option :domain, type: :string, desc: "Domain gem name or path"
      option :version, type: :string, desc: "Domain version"
      option :dir, type: :string, desc: "Output directory (default: {domain}_app)"
      option :force, type: :boolean, desc: "Overwrite without prompting"
      # Scaffolds a complete Sinatra application from the domain definition.
      #
      # Resolves the domain, determines the output directory, and generates
      # all application files. Uses ConflictHandler for safe file writing.
      #
      # @return [void]
      def generate_sinatra
        domain = resolve_domain_option
        return unless domain

        app_name = options[:dir] || "#{Hecks::Utils.underscore(domain.module_name)}_app"
        generate_sinatra_app(domain, app_name)
      end

      private

      # Generates the full Sinatra app directory structure.
      #
      # Creates the output directory and config/ subdirectory, then writes
      # Gemfile, config.ru, app.rb, and config/hecks.rb. Prints next steps.
      #
      # @param domain [DomainModel::Structure::Domain] the domain to scaffold from
      # @param dir [String] the output directory path
      # @return [void]
      def generate_sinatra_app(domain, dir)
        FileUtils.mkdir_p(dir)
        FileUtils.mkdir_p(File.join(dir, "config"))

        write_or_diff(File.join(dir, "Gemfile"), sinatra_gemfile(domain))
        write_or_diff(File.join(dir, "config.ru"), sinatra_config_ru)
        write_or_diff(File.join(dir, "app.rb"), sinatra_app_rb(domain))
        write_or_diff(File.join(dir, "config/hecks.rb"), sinatra_hecks_config(domain))

        say "Generated Sinatra app: #{dir}/", :green
        say "  Gemfile      — dependencies"
        say "  config.ru    — rackup entry point"
        say "  app.rb       — routes (edit this!)"
        say "  config/hecks.rb — domain configuration"
        say ""
        say "Next steps:"
        say "  cd #{dir}"
        say "  bundle install"
        say "  ruby app.rb"
      end

      # Generates the Gemfile content for the Sinatra app.
      #
      # @param domain [DomainModel::Structure::Domain] the domain (for gem reference)
      # @return [String] the Gemfile content
      def sinatra_gemfile(domain)
        <<~RUBY
          source "https://rubygems.org"

          gem "sinatra"
          gem "sinatra-contrib"
          gem "hecks"
          gem "#{domain.gem_name}", path: "../#{domain.gem_name}"
        RUBY
      end

      # Generates the config.ru content for Rack.
      #
      # @return [String] the config.ru content
      def sinatra_config_ru
        <<~RUBY
          require_relative "app"
          run App
        RUBY
      end

      # Generates the main app.rb with CRUD and query routes for all aggregates.
      #
      # For each aggregate, generates:
      # - GET routes for each custom query
      # - GET /resources for listing all
      # - GET /resources/:id for finding by ID
      # - POST /resources for creation (if a Create* command exists)
      # - DELETE /resources/:id for deletion
      #
      # @param domain [DomainModel::Structure::Domain] the domain
      # @return [String] the app.rb source code
      def sinatra_app_rb(domain)
        mod = domain_module_name(domain.name)
        routes = []

        domain.aggregates.each do |agg|
          slug = domain_aggregate_slug(agg.name)
          klass = "#{agg.name}"

          # Queries first
          agg.queries.each do |query|
            qn = Hecks::Utils.underscore(query.name)
            params = query.block.parameters
            if params.empty?
              routes << "  get '/#{slug}/#{qn}' do\n    json #{klass}.#{qn}.map { |r| serialize(r) }\n  end"
            else
              args = params.map { |_, n| "params[:#{n}]" }.join(", ")
              routes << "  get '/#{slug}/#{qn}' do\n    json #{klass}.#{qn}(#{args}).map { |r| serialize(r) }\n  end"
            end
          end

          # CRUD
          routes << "  get '/#{slug}' do\n    json #{klass}.all.map { |r| serialize(r) }\n  end"
          routes << "  get '/#{slug}/:id' do\n    result = #{klass}.find(params[:id])\n    halt 404, json(error: 'Not found') unless result\n    json serialize(result)\n  end"

          create_cmd = agg.commands.find { |c| c.name.start_with?("Create") }
          if create_cmd
            method_name = domain_command_method(create_cmd.name, agg.name)
            routes << "  post '/#{slug}' do\n    attrs = JSON.parse(request.body.read, symbolize_names: true)\n    result = #{klass}.#{method_name}(**attrs)\n    status 201\n    json serialize(result)\n  end"
          end

          routes << "  delete '/#{slug}/:id' do\n    #{klass}.delete(params[:id])\n    json deleted: params[:id]\n  end"
        end

        <<~RUBY
          require "sinatra"
          require "sinatra/json"
          require_relative "config/hecks"

          class App < Sinatra::Base
            helpers Sinatra::JSON

            before do
              content_type :json
              headers "Access-Control-Allow-Origin" => "*",
                      "Access-Control-Allow-Methods" => "GET, POST, PATCH, DELETE, OPTIONS",
                      "Access-Control-Allow-Headers" => "Content-Type"
            end

            options "*" do
              200
            end

          #{routes.join("\n\n")}

            private

            def serialize(obj)
              Hecks::Utils.object_attr_names(obj).each_with_object({}) do |name, h|
                next unless obj.respond_to?(name)
                val = obj.send(name)
                h[name] = val.is_a?(Time) ? val.iso8601 : val
              end
            end
          end
        RUBY
      end

      # Generates the config/hecks.rb configuration file for the Sinatra app.
      #
      # Loads the domain gem, evaluates its hecks_domain.rb, and boots Hecks
      # with memory adapters. Includes commented-out SQL configuration.
      #
      # @param domain [DomainModel::Structure::Domain] the domain
      # @return [String] the configuration file content
      def sinatra_hecks_config(domain)
        <<~RUBY
          require "hecks"
          require "#{domain.gem_name}"

          # Load the domain
          domain_file = File.join(Gem.loaded_specs["#{domain.gem_name}"]&.full_gem_path || "../#{domain.gem_name}", "hecks_domain.rb")
          DOMAIN = eval(File.read(domain_file), TOPLEVEL_BINDING, domain_file)

          # Boot with memory adapters (swap to SQL for production)
          APP = Hecks.load(DOMAIN)

          # Uncomment for SQL persistence:
          # Hecks.configure do
          #   domain "#{domain.gem_name}"
          #   adapter :sql, database: :sqlite, name: "#{Hecks::Utils.underscore(domain.module_name)}.db"
          #   include_ad_hoc_queries
          # end
        RUBY
      end
    end
  end
end
