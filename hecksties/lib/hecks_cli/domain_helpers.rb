# Hecks::DomainHelpers
#
# Shared helpers for CLI commands that work with domains:
# resolving domain files, loading them, finding installed gems.
# Included in CLI so all registered commands can use them.
#
module Hecks
  module DomainHelpers
    private

    def find_domain_file
      path = Dir[File.join(Dir.pwd, "*Bluebook")].first
      File.exist?(path) ? path : nil
    end

    def resolve_domain_option
      if options[:domain]
        resolve_domain(options[:domain])
      else
        file = find_domain_file
        if file
          load_domain_file(file)
        else
          domains = find_installed_domains
          if domains.empty?
            say "No Bluebook found and no --domain specified.", :red
          else
            say "No Bluebook found. Use --domain to specify one:", :red
            domains.each { |name, versions| say "  --domain #{name} (#{versions.map { |v| "v#{v}" }.join(", ")})", :yellow }
          end
          nil
        end
      end
    end

    def resolve_domain(path_or_name)
      if path_or_name.nil?
        file = find_domain_file
        return nil unless file
        load_domain_file(file)
      elsif File.directory?(path_or_name)
        file = Dir[File.join(path_or_name, "*Bluebook")].first
        return nil unless File.exist?(file)
        load_domain_file(file)
      elsif File.exist?(path_or_name)
        load_domain_file(path_or_name)
      else
        local = File.join(Dir.pwd, path_or_name, "Bluebook")
        File.exist?(local) ? load_domain_file(local) : nil
      end
    end

    def load_domain_file(file)
      Kernel.load(file)
      domain = Hecks.last_domain
      domain.source_path = file
      domain
    end

    def find_installed_domains
      ::Gem::Specification.select { |spec| Dir[File.join(spec.full_gem_path, "*Bluebook")].any? }
        .group_by(&:name).map { |name, specs| [name, specs.map(&:version).sort.reverse] }
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
  end
end
