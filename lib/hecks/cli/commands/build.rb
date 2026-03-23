# Hecks::CLI build command
#
module Hecks
  class CLI < Thor
    desc "build", "Generate the domain gem"
    option :domain, type: :string, desc: "Domain gem name or path"
    option :version, type: :string, desc: "Domain version"
    def build
      domain = resolve_domain_option
      return unless domain
      validator = Validator.new(domain)
      unless validator.valid?
        say "Domain validation failed:", :red
        validator.errors.each { |e| say "  - #{e}", :red }
        return
      end
      versioner = Versioner.new(".")
      version = versioner.next
      output = Hecks.build(domain, version: version)
      say "Built #{domain.gem_name} v#{version}", :green
      say "  Output: #{output}/"
      say "  Docs: #{output}/docs/"
    end
  end
end
