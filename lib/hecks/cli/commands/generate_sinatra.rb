# Hecks::CLI generate sinatra command
#
module Hecks
  class CLI < Thor
    desc "generate:sinatra", "Scaffold a Sinatra app from a domain"
    map "generate:sinatra" => :generate_sinatra
    option :domain, type: :string, desc: "Domain gem name or path"
    option :dir, type: :string, desc: "Output directory (default: {domain}_app)"
    def generate_sinatra
      domain = resolve_domain_option
      return unless domain

      app_name = options[:dir] || "#{Hecks::Utils.underscore(domain.module_name)}_app"
      generate_sinatra_app(domain, app_name)
    end

    private

    def generate_sinatra_app(domain, dir)
      FileUtils.mkdir_p(dir)
      FileUtils.mkdir_p(File.join(dir, "config"))

      File.write(File.join(dir, "Gemfile"), sinatra_gemfile(domain))
      File.write(File.join(dir, "config.ru"), sinatra_config_ru)
      File.write(File.join(dir, "app.rb"), sinatra_app_rb(domain))
      File.write(File.join(dir, "config/hecks.rb"), sinatra_hecks_config(domain))

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

    def sinatra_gemfile(domain)
      <<~RUBY
        source "https://rubygems.org"

        gem "sinatra"
        gem "sinatra-contrib"
        gem "hecks"
        gem "#{domain.gem_name}", path: "../#{domain.gem_name}"
      RUBY
    end

    def sinatra_config_ru
      <<~RUBY
        require_relative "app"
        run App
      RUBY
    end

    def sinatra_app_rb(domain)
      mod = domain.module_name + "Domain"
      routes = []

      domain.aggregates.each do |agg|
        slug = Hecks::Utils.underscore(agg.name) + "s"
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
          method_name = Hecks::Utils.underscore(create_cmd.name).sub(/_#{Hecks::Utils.underscore(agg.name)}$/, "")
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
            obj.class.instance_method(:initialize).parameters.each_with_object({}) do |(_, name), h|
              next unless name && obj.respond_to?(name)
              val = obj.send(name)
              h[name] = val.is_a?(Time) ? val.iso8601 : val
            end
          end
        end
      RUBY
    end

    def sinatra_hecks_config(domain)
      <<~RUBY
        require "hecks"
        require "#{domain.gem_name}"

        # Load the domain
        domain_file = File.join(Gem.loaded_specs["#{domain.gem_name}"]&.full_gem_path || "../#{domain.gem_name}", "hecks_domain.rb")
        DOMAIN = eval(File.read(domain_file), TOPLEVEL_BINDING, domain_file)

        # Boot with memory adapters (swap to SQL for production)
        APP = Hecks::Services::Application.new(DOMAIN)

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
