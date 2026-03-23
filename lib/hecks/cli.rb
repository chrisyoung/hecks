# Hecks::CLI
#
# Command-line interface. Each command is its own file under cli/.
#
require "thor"
require "fileutils"

module Hecks
  class CLI < Thor
    private

    def find_domain_file
      path = File.join(Dir.pwd, "domain.rb")
      File.exist?(path) ? path : nil
    end

    def resolve_domain(path_or_name)
      if path_or_name.nil?
        file = find_domain_file
        return nil unless file
        load_domain(file)
      elsif File.directory?(path_or_name)
        file = File.join(path_or_name, "domain.rb")
        return nil unless File.exist?(file)
        load_domain(file)
      elsif File.exist?(path_or_name)
        load_domain(path_or_name)
      else
        # Check local subdirectory
        local = File.join(Dir.pwd, path_or_name, "domain.rb")
        if File.exist?(local)
          load_domain(local)
        else
          # Check installed gems
          resolve_domain_from_gem(path_or_name)
        end
      end
    end

    def resolve_domain_from_gem(gem_name)
      require gem_name
      spec = Gem.loaded_specs[gem_name]
      return nil unless spec
      domain_file = File.join(spec.full_gem_path, "domain.rb")
      return nil unless File.exist?(domain_file)
      load_domain(domain_file)
    rescue LoadError
      nil
    end

    def load_domain(file)
      domain = eval(File.read(file), binding, file)
      domain.source_path = file
      domain
    end

    def domain_template(name)
      <<~RUBY
        Hecks.domain "#{name}" do
          aggregate "Example" do
            attribute :name, String

            validation :name, presence: true

            command "CreateExample" do
              attribute :name, String
            end
          end
        end
      RUBY
    end

    Dir[File.join(__dir__, "cli/commands/*.rb")].each { |f| require f }
  end
end
