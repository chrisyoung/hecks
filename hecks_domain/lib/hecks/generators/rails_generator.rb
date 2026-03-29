# Hecks::Generators::RailsGenerator
#
# Generates a bootstrapped Rails app with a Hecks domain loaded and
# ready to use. Not a full CRUD scaffold — just a starting point.
# The user builds controllers and views on top.
#
#   Hecks::Generators::RailsGenerator.new(domain).generate(output_dir: ".")
#   # => "./blog_rails/"
#
module Hecks
  module Generators
    class RailsGenerator
      include HecksTemplating::NamingHelpers

      def initialize(domain)
        @domain = domain
      end

      def generate(output_dir: ".")
        slug = domain_slug(@domain.name)
        @root = File.join(output_dir, "#{slug}_rails")
        @gem_name = domain_gem_name(@domain.name)
        @mod_name = domain_module_name(@domain.name)

        write_gemfile
        write_config
        write_landing_page
        write_boilerplate
        build_domain_gem
        @root
      end

      private

      def write_gemfile
        write "Gemfile", <<~RUBY
          source "https://rubygems.org"
          gem "rails", "~> 8.0"
          gem "propshaft"
          gem "puma", ">= 5.0"
          gem "#{@gem_name}", path: "./#{@gem_name}"
          gem "hecks"
        RUBY
      end

      def write_config
        write "config/application.rb", <<~RUBY
          require_relative "boot"
          require "rails"
          require "action_controller/railtie"
          require "action_view/railtie"

          module #{domain_constant_name(@domain.name)}Rails
            class Application < Rails::Application
              config.load_defaults 8.0
              config.eager_load = false
            end
          end
        RUBY

        write "config/boot.rb", <<~RUBY
          ENV["BUNDLE_GEMFILE"] ||= File.expand_path("../Gemfile", __dir__)
          require "bundler/setup"
        RUBY

        write "config/environment.rb", <<~RUBY
          require_relative "application"
          Rails.application.initialize!
        RUBY

        write "config/routes.rb", <<~RUBY
          Rails.application.routes.draw do
            # Your domain routes go here.
            # Example:
            #   resources :posts
          end
        RUBY

        write "config/puma.rb", <<~RUBY
          threads_count = ENV.fetch("RAILS_MAX_THREADS", 3)
          threads threads_count, threads_count
          port ENV.fetch("PORT", 3000)
          environment ENV.fetch("RAILS_ENV", "development")
        RUBY

        write "config/initializers/hecks.rb", <<~RUBY
          require "hecks"
          require "#{@gem_name}"

          Hecks.configure do
            domain "#{@gem_name}"
            adapter :memory
          end
        RUBY
      end

      def write_landing_page
        # Copy the actual Rails 8 welcome page and modify only 3 things:
        # 1. Title → "Hecks on Rails!"
        # 2. Logo background → animated rust gradient
        # 3. Version info → domain info
        source = File.join(
          ::Gem.loaded_specs["railties"].full_gem_path,
          "lib/rails/templates/rails/welcome/index.html.erb"
        )

        if File.exist?(source)
          html = File.read(source)
          # Strip ERB tags (static file, no Rails runtime)
          html = html.gsub(/<%= Rails\.version %>/, "8.x")
                     .gsub(/<%= Rack\.release %>/, "")
                     .gsub(/<%= RUBY_DESCRIPTION %>/, RUBY_DESCRIPTION)
          # 1. Title
          html = html.sub("<title>Ruby on Rails 8.x</title>", "<title>Hecks on Rails!</title>")
          # 2. Logo gradient border
          html = html.sub(
            "background: #D30001;",
            "background: linear-gradient(135deg, #8B4513, #CD7F32, #B87333, #A0522D, #8B4513);\n      background-size: 300% 300%;\n      animation: rust 4s ease infinite;"
          )
          html = html.sub("</style>", "    @keyframes rust {\n      0% { background-position: 0% 50%; }\n      50% { background-position: 100% 50%; }\n      100% { background-position: 0% 50%; }\n    }\n  </style>")
          # 3. Version info → domain info
          aggs = @domain.aggregates.map(&:name).join(", ")
          html = html.sub(
            /<li><strong>Rails version:<\/strong>.*<\/li>/,
            "<li><strong>Domain:</strong> #{@domain.name}</li>"
          )
          html = html.sub(
            /<li><strong>Rack version:<\/strong>.*<\/li>/,
            "<li><strong>Aggregates:</strong> #{aggs}</li>"
          )
          html = html.sub(
            /<li><strong>Ruby version:<\/strong>.*<\/li>/,
            "<li><strong>Hecks on Rails!</strong></li>"
          )
        else
          html = "<html><body><h1>Hecks on Rails!</h1><p>#{@domain.name} Domain</p></body></html>"
        end

        write "public/index.html", html
      end

      def write_boilerplate
        write "Rakefile", <<~RUBY
          require_relative "config/application"
          Rails.application.load_tasks
        RUBY

        write "config.ru", <<~RUBY
          require_relative "config/environment"
          run Rails.application
        RUBY

        write "app/controllers/application_controller.rb", <<~RUBY
          class ApplicationController < ActionController::Base
          end
        RUBY

        write "bin/rails", <<~RUBY
          #!/usr/bin/env ruby
          APP_PATH = File.expand_path("../config/application", __dir__)
          require_relative "../config/boot"
          require "rails/commands"
        RUBY
        FileUtils.chmod(0o755, File.join(@root, "bin/rails"))
      end

      def build_domain_gem
        Hecks.build(@domain, output_dir: @root)
        # Copy hecks_domain.rb for reference
        if @domain.source_path && File.exist?(@domain.source_path)
          FileUtils.cp(@domain.source_path, File.join(@root, "hecks_domain.rb"))
        end
      end

      def write(path, content)
        full = File.join(@root, path)
        FileUtils.mkdir_p(File.dirname(full))
        File.write(full, content)
      end
    end
  end
end
