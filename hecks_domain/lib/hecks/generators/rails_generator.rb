# Hecks::Generators::RailsGenerator
#
# Runs `rails new` to create a real Rails app, then patches it:
# - Adds hecks + domain gem to Gemfile
# - Adds config/initializers/hecks.rb
# - Modifies the welcome page with Hecks branding
# - Builds the domain gem inside the app
#
#   Hecks::Generators::RailsGenerator.new(domain).generate(output_dir: ".")
#
require "pathname"

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

        run_rails_new
        patch_gemfile
        add_hecks_initializer
        patch_welcome_page
        @root
      end

      private

      def run_rails_new
        app_name = domain_slug(@domain.name)
        cmd = "rails new #{@root} --name #{app_name} --skip-active-record --skip-test --skip-system-test --skip-action-mailer --skip-action-mailbox --skip-action-text --skip-active-job --skip-active-storage --skip-action-cable --skip-jbuilder --skip-hotwire --minimal --quiet"
        unless system(cmd)
          raise "rails new failed. Is Rails installed? (gem install rails)"
        end
      end

      def patch_gemfile
        gemfile = File.join(@root, "Gemfile")
        content = File.read(gemfile)
        # Add hecks and all sub-gems as path references for local dev
        if @domain.source_path
          hecks_root = File.expand_path("../..", File.dirname(@domain.source_path))
          rel = Pathname.new(hecks_root).relative_path_from(Pathname.new(File.expand_path(@root)))
          content += "\ngem \"hecks\", path: \"#{rel}\"\n"
        else
          content += "\ngem \"hecks\"\n"
        end
        content += "gem \"#{@gem_name}\", path: \"../#{@gem_name}\"\n"
        File.write(gemfile, content)
      end

      def add_hecks_initializer
        write "config/initializers/hecks.rb", <<~RUBY
          require "hecks"
          require "#{@gem_name}"

          Hecks.configure do
            domain "#{@gem_name}"
            adapter :memory
          end
        RUBY
      end

      def patch_welcome_page
        # Copy the Rails welcome page ERB, resolve tags, add Hecks version
        railties = ::Gem.loaded_specs["railties"]
        return unless railties

        source = File.join(railties.full_gem_path, "lib/rails/templates/rails/welcome/index.html.erb")
        return unless File.exist?(source)

        html = File.read(source)

        # Resolve ERB tags to static values
        rails_v = ::Gem.loaded_specs["railties"]&.version&.to_s || "8"
        rack_v = ::Gem.loaded_specs["rack"]&.version&.to_s || ""
        html = html.gsub(/<%= Rails\.version %>/, rails_v)
                   .gsub(/<%= Rack\.release %>/, rack_v)
                   .gsub(/<%= RUBY_DESCRIPTION %>/, RUBY_DESCRIPTION)

        # Add Hecks version after Rack version
        html = html.sub(
          %r{(<li><strong>Rack version:</strong>.*?</li>)},
          "\\1\n    <li><strong>Hecks version:</strong> #{Hecks::VERSION}</li>"
        )

        write "public/index.html", html
      end

      def write(path, content)
        full = File.join(@root, path)
        FileUtils.mkdir_p(File.dirname(full))
        File.write(full, content)
      end
    end
  end
end
