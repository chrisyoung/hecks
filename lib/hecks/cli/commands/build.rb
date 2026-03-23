# Hecks::CLI build command
#
module Hecks
  class CLI < Thor
    desc "build", "Generate the domain gem from domain.rb"
    def build
      domain_file = find_domain_file
      unless domain_file
        say "No domain.rb found in current directory", :red
        return
      end
      domain = load_domain(domain_file)
      validator = Validator.new(domain)
      unless validator.valid?
        say "Domain validation failed:", :red
        validator.errors.each { |e| say "  - #{e}", :red }
        return
      end
      versioner = Versioner.new(".")
      version = versioner.next
      generator = Generators::Infrastructure::DomainGemGenerator.new(domain, version: version)
      output = generator.generate
      say "Built #{domain.gem_name} v#{version}", :green
      say "  Output: #{output}/"
    end
  end
end
