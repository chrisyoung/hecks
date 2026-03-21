# rails generate hecks:init
#
# Sets up a Hecks domain gem in a Rails app:
#   1. Creates config/initializers/hecks.rb
#   2. Creates app/models/HECKS_README.md explaining the setup
#
# The domain gem must already be built and in the Gemfile.
#
require "rails/generators"

module Hecks
  class InitGenerator < ::Rails::Generators::Base
    desc "Set up a Hecks domain gem in your Rails app"

    def detect_domain_gem
      @gem_dir = Dir.glob(::Rails.root.join("*_domain")).first
      unless @gem_dir
        say "No domain gem found (looking for *_domain/ directory)", :red
        say "Build one first with `hecks build` and add it to your Gemfile."
        raise SystemExit
      end

      @gem_name = File.basename(@gem_dir)
      @domain_module = @gem_name.split("_").map(&:capitalize).join.sub(/Domain$/, "") + "Domain"
      say "Found domain gem: #{@gem_name}", :green
    end

    def create_initializer
      initializer_path = ::Rails.root.join("config/initializers/hecks.rb")
      if File.exist?(initializer_path)
        say "config/initializers/hecks.rb already exists", :yellow
        return
      end

      create_file "config/initializers/hecks.rb", <<~RUBY
        Hecks.configure do
          domain "#{@gem_name}"
          adapter :memory
        end
      RUBY
    end

    def create_hecks_readme
      create_file "app/models/HECKS_README.md", <<~MD
        # Domain Models

        This app uses [Hecks](https://github.com/hecks) for domain modeling.
        There are no ActiveRecord model files here — domain objects come from
        the `#{@gem_name}` gem.

        ## Usage

        ```ruby
        Pizza.create(name: "Margherita", description: "Classic")
        Pizza.find(id)
        Pizza.all
        Pizza.count
        Pizza.delete(id)

        pizza.toppings.create(name: "Mozzarella", amount: 2)
        pizza.toppings.each { |t| puts t.name }
        ```

        ## Changing the Domain

        The domain is defined in a standalone Hecks project. To modify it:

        1. Go to the Hecks project where `domain.rb` lives
        2. Run `hecks console` to edit interactively
        3. Run `hecks build` to generate a new version of the gem
        4. Update the gem version in this app's Gemfile
        5. `bundle update #{@gem_name}`

        ## Where's the Code?

        - Domain classes: `#{@gem_name}/lib/` (the gem)
        - Initializer: `config/initializers/hecks.rb`
        - This file: `app/models/HECKS_README.md`
      MD
    end

    def print_summary
      say ""
      say "Hecks initialized!", :green
      say "  config/initializers/hecks.rb   — boots the domain"
      say "  app/models/HECKS_README.md     — explains the setup"
      say ""
      say "Domain objects are ready: Pizza.create, Pizza.find, etc."
    end
  end
end
