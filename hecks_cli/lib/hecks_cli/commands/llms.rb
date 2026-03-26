# Hecks::CLI::Domain#llms
#
# Generates an AI-readable plain text summary (llms.txt) of the domain model.
# Outputs domain name, aggregates with attributes and types, commands with
# parameters, queries, specifications, policies, validation rules, invariants,
# and reactive flow chains.
#
#   hecks domain llms [--domain NAME]
#
module Hecks
  class CLI < Thor
    class Domain < Thor
      desc "llms", "Generate AI-readable llms.txt summary of the domain"
      option :domain, type: :string, desc: "Domain gem name or path"
      option :version, type: :string, desc: "Domain version"
      # Generates and prints an llms.txt summary of the domain model.
      #
      # Resolves the domain from --domain option or auto-detection, then
      # delegates to LlmsGenerator to produce the AI-readable output.
      #
      # @return [void]
      def llms
        domain = resolve_domain_option
        return unless domain

        puts Hecks::LlmsGenerator.new(domain).generate
      end
    end
  end
end
