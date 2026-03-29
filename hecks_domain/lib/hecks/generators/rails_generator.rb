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
        build_domain_gem
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
        # Relative path to hecks if source_path is known, otherwise bare gem
        if @domain.source_path
          hecks_root = File.expand_path("../..", File.dirname(@domain.source_path))
          rel = Pathname.new(hecks_root).relative_path_from(Pathname.new(File.expand_path(@root)))
          content += "\ngem \"hecks\", path: \"#{rel}\"\n"
        else
          content += "\ngem \"hecks\"\n"
        end
        content += "gem \"#{@gem_name}\", path: \"./#{@gem_name}\"\n"
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
        # Find the welcome page ERB in the railties gem
        railties = ::Gem.loaded_specs["railties"]
        return unless railties

        source = File.join(railties.full_gem_path, "lib/rails/templates/rails/welcome/index.html.erb")
        return unless File.exist?(source)

        html = File.read(source)

        # Resolve ERB tags to static values
        html = html.gsub(/<%= Rails\.version %>/, "8")
                   .gsub(/<%= Rack\.release %>/, "")
                   .gsub(/<%= RUBY_DESCRIPTION %>/, RUBY_DESCRIPTION)

        # 1. Title
        html = html.sub(/Ruby on Rails \S+/, "Hecks on Rails!")

        # 2. Logo: red → animated rust gradient
        html = html.sub(
          "background: #D30001;",
          "background: linear-gradient(135deg, #8B4513, #CD7F32, #B87333, #A0522D, #8B4513);\n      background-size: 300% 300%;\n      animation: rust 4s ease infinite;"
        )
        html = html.sub(
          "  </style>",
          "    @keyframes rust {\n      0% { background-position: 0% 50%; }\n      50% { background-position: 100% 50%; }\n      100% { background-position: 0% 50%; }\n    }\n  </style>"
        )

        # 3. Version info → domain info
        aggs = @domain.aggregates.map(&:name).join(", ")
        html = html.sub(/<li><strong>Rails version:<\/strong>.*?<\/li>/, "<li><strong>Domain:</strong> #{@domain.name}</li>")
        html = html.sub(/<li><strong>Rack version:<\/strong>.*?<\/li>/, "<li><strong>Aggregates:</strong> #{aggs}</li>")
        html = html.sub(/<li><strong>Ruby version:<\/strong>.*?<\/li>/, "<li><strong>Hecks on Rails!</strong></li>")

        write "public/index.html", html
      end

      def build_domain_gem
        Hecks.build(@domain, output_dir: @root)
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
