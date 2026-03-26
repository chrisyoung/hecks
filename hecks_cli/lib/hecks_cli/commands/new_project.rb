# Hecks::CLI#new_project
#
# Scaffolds a new Hecks project directory with a domain definition, app.rb,
# Gemfile, spec setup, and gitignore. Provides everything needed to start
# modeling a domain immediately.
#
#   hecks new my_app
#
module Hecks
  class CLI < Thor
    desc "new NAME", "Create a new Hecks project"
    # Creates a new Hecks project directory with all starter files.
    #
    # Generates:
    # - hecks_domain.rb: starter domain definition
    # - app.rb: boot script with usage comments
    # - Gemfile: with hecks dependency
    # - spec/spec_helper.rb: RSpec setup with Hecks boot
    # - .gitignore: ignores .gem files and domain output
    # - .rspec: RSpec configuration
    #
    # Refuses to overwrite an existing directory.
    #
    # @param name [String] the project directory name (also used to derive
    #   the PascalCase domain name)
    # @return [void]
    def new_project(name)
      pascal = name.split(/[_\-\s]/).map(&:capitalize).join
      dir = name

      if File.exist?(dir)
        say "Directory #{dir} already exists", :red
        return
      end

      FileUtils.mkdir_p(File.join(dir, "spec"))

      write_or_diff(File.join(dir, "hecks_domain.rb"), domain_template(pascal))
      write_or_diff(File.join(dir, "app.rb"), app_template)
      write_or_diff(File.join(dir, "Gemfile"), gemfile_template)
      write_or_diff(File.join(dir, "spec", "spec_helper.rb"), spec_helper_template)
      write_or_diff(File.join(dir, ".gitignore"), gitignore_template)
      write_or_diff(File.join(dir, ".rspec"), rspec_template)

      say "Created #{dir}/", :green
      say "  hecks_domain.rb"
      say "  app.rb"
      say "  Gemfile"
      say "  spec/spec_helper.rb"
      say "  .gitignore"
      say "  .rspec"
      say ""
      say "Get started:"
      say "  cd #{dir}"
      say "  bundle install"
      say "  ruby app.rb"
    end

    map "new" => :new_project

    private

    # Generates a starter domain template with one aggregate and command.
    #
    # @param name [String] the PascalCase domain name
    # @return [String] the domain definition source code
    def domain_template(name)
      <<~RUBY
        Hecks.domain "#{name}" do
          aggregate "Example" do
            attribute :name, String

            command "CreateExample" do
              attribute :name, String
            end
          end
        end
      RUBY
    end

    # Generates the app.rb boot script.
    #
    # @return [String] the app.rb source code
    def app_template
      <<~RUBY
        require "hecks"

        app = Hecks.boot(__dir__)

        # Start building:
        #   Example.create(name: "Hello")
        #   Example.all
      RUBY
    end

    # Generates the Gemfile, pointing to the local hecks gem if running
    # from source, or the published gem otherwise.
    #
    # @return [String] the Gemfile content
    def gemfile_template
      hecks_spec = ::Gem.loaded_specs["hecks"]
      if hecks_spec && hecks_spec.full_gem_path != File.expand_path("../../../..", __FILE__)
        gem_line = 'gem "hecks"'
      else
        hecks_root = File.expand_path("../../../..", __FILE__)
        gem_line = "gem \"hecks\", path: \"#{hecks_root}\""
      end

      <<~RUBY
        source "https://rubygems.org"
        #{gem_line}
      RUBY
    end

    # Generates the spec/spec_helper.rb with Hecks boot.
    #
    # @return [String] the spec_helper.rb source code
    def spec_helper_template
      <<~RUBY
        require "hecks"
        app = Hecks.boot(File.join(__dir__, ".."))

        RSpec.configure do |config|
          config.order = :random
        end
      RUBY
    end

    # Generates the .gitignore content.
    #
    # @return [String] the gitignore content
    def gitignore_template
      <<~TEXT
        *.gem
        *_domain/
      TEXT
    end

    # Generates the .rspec configuration.
    #
    # @return [String] the .rspec content
    def rspec_template
      <<~TEXT
        --format documentation
        --color
        --require spec_helper
      TEXT
    end
  end
end
