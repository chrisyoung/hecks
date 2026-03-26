# Hecks::CLI::Domain#generate_stub
#
# Scaffolds a single domain file for hand-editing. After boot switched to
# in-memory compilation, this is the way to get an editable .rb file for
# custom command logic, query implementations, etc. Uses ConflictHandler
# to show diffs if the file already exists.
#
#   hecks domain generate:stub Command Withdraw
#   hecks domain generate:stub Query ActiveUsers
#   hecks domain generate:stub Aggregate Pizza
#
require_relative "../stub_generator"

module Hecks
  class CLI < Thor
    class Domain < Thor
      desc "generate:stub TYPE NAME", "Scaffold a domain file for hand-editing"
      map "generate:stub" => :generate_stub
      option :domain, type: :string, desc: "Domain gem name or path"
      option :force, type: :boolean, desc: "Overwrite without prompting"
      def generate_stub(type, name)
        domain = resolve_domain_option
        return unless domain

        type = type.downcase
        result = StubGenerator.new(domain, type, name).generate
        unless result
          say "Unknown type '#{type}'. Use: command, query, aggregate, workflow, service, policy, specification", :red
          return
        end

        result.each do |path, content|
          write_or_diff(path, content)
        end
      end
    end
  end
end
