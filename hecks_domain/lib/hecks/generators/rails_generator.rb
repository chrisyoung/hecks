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
        agg_items = @domain.aggregates.map do |a|
          cmds = a.commands.map(&:name).join(", ")
          "              <li><strong>#{a.name}</strong> — #{cmds}</li>"
        end.join("\n")
        first_agg = @domain.aggregates.first&.name || "Aggregate"

        write "public/index.html", <<~HTML
          <!DOCTYPE html>
          <html>
          <head>
            <meta charset="utf-8">
            <meta name="viewport" content="width=device-width, initial-scale=1">
            <title>Hecks on Rails!</title>
            <style>
              body {
                font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif;
                margin: 0; padding: 40px 20px;
                background: #f5f5f5; color: #333;
                display: flex; justify-content: center;
              }
              .container { max-width: 720px; width: 100%; }
              .hero {
                background: #fff;
                border-radius: 12px;
                padding: 48px;
                text-align: center;
                position: relative;
                border: 3px solid transparent;
              }
              .hero::before {
                content: "";
                position: absolute; inset: -3px;
                border-radius: 14px;
                background: linear-gradient(135deg, #8B4513, #CD7F32, #B87333, #A0522D, #8B4513);
                background-size: 300% 300%;
                animation: rust 4s ease infinite;
                z-index: -1;
              }
              @keyframes rust {
                0% { background-position: 0% 50%; }
                50% { background-position: 100% 50%; }
                100% { background-position: 0% 50%; }
              }
              h1 { font-size: 2.2rem; margin: 0 0 4px; }
              h1 span { color: #CD7F32; }
              .version { color: #999; font-size: 0.9rem; margin-bottom: 24px; }
              .section {
                background: #fafafa; border: 1px solid #e0e0e0;
                border-radius: 8px; padding: 20px 24px;
                margin-top: 20px; text-align: left;
              }
              .section h3 { margin: 0 0 8px; color: #8B4513; }
              .section ul { margin: 0; padding-left: 20px; }
              .section li { line-height: 1.8; }
              .section code {
                background: #f0ebe3; padding: 1px 5px;
                border-radius: 3px; font-size: 0.9em;
              }
              .next-steps { margin-top: 24px; text-align: left; }
              .next-steps p { line-height: 1.8; color: #666; }
              .next-steps code { background: #f0ebe3; padding: 1px 5px; border-radius: 3px; }
            </style>
          </head>
          <body>
            <div class="container">
              <div class="hero">
                <h1>Hecks <span>on Rails!</span></h1>
                <p class="version">#{@domain.name} Domain</p>
              </div>

              <div class="section">
                <h3>Your domain is loaded</h3>
                <ul>
          #{agg_items}
                </ul>
              </div>

              <div class="next-steps">
                <p>
                  Add routes in <code>config/routes.rb</code>,
                  create a controller, and start using your domain:
                </p>
                <p><code>#{first_agg}.create(name: "Hello World")</code></p>
                <p>
                  No ActiveRecord. No migrations. Hecks handles the domain.
                  Rails handles the web.
                </p>
              </div>
            </div>
          </body>
          </html>
        HTML
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
