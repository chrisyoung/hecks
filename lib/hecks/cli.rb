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
      path = File.join(Dir.pwd, "hecks_domain.rb")
      File.exist?(path) ? path : nil
    end

    def resolve_domain(path_or_name)
      if path_or_name.nil?
        file = find_domain_file
        return nil unless file
        load_domain(file)
      elsif File.directory?(path_or_name)
        file = File.join(path_or_name, "hecks_domain.rb")
        return nil unless File.exist?(file)
        load_domain(file)
      elsif File.exist?(path_or_name)
        load_domain(path_or_name)
      else
        # Check local subdirectory
        local = File.join(Dir.pwd, path_or_name, "hecks_domain.rb")
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
      domain_file = File.join(spec.full_gem_path, "hecks_domain.rb")
      return nil unless File.exist?(domain_file)
      load_domain(domain_file)
    rescue LoadError
      nil
    end

    def resolve_domain_option
      if options[:domain]
        resolve_domain(options[:domain])
      else
        file = find_domain_file
        if file
          load_domain(file)
        else
          domains = find_installed_domains
          if domains.empty?
            say "No hecks_domain.rb found and no --domain specified.", :red
          else
            say "No hecks_domain.rb found. Use --domain to specify one:", :red
            domains.each do |name, versions|
              say "  --domain #{name} (#{versions.map { |v| "v#{v}" }.join(", ")})", :yellow
            end
          end
          nil
        end
      end
    end

    def find_installed_domains
      Gem::Specification.select do |spec|
        File.exist?(File.join(spec.full_gem_path, "hecks_domain.rb"))
      end.group_by(&:name).map do |name, specs|
        versions = specs.map(&:version).sort.reverse
        [name, versions]
      end
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
