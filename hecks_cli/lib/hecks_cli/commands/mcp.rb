# Hecks::CLI::Domain#mcp
#
# Starts an MCP (Model Context Protocol) server. Without --domain, launches the
# build-oriented McpServer. With --domain, launches MCP::DomainServer exposing
# the domain's aggregates, commands, and queries as MCP tools.
#
#   hecks domain mcp [--domain NAME]
#
module Hecks
  class CLI < Thor
    class Domain < Thor
      desc "mcp", "Start MCP server — build domains (default) or serve one (--domain)"
      option :domain, type: :string, desc: "Domain gem name or path (serves it as MCP tools)"
      option :version, type: :string, desc: "Domain version"
      # Starts an MCP server for AI agent integration.
      #
      # Two modes:
      # - Without --domain: starts the build-oriented McpServer with tools for
      #   creating and modifying domain definitions
      # - With --domain: starts MCP::DomainServer exposing the specified domain's
      #   aggregates, commands, and queries as callable MCP tools
      #
      # Requires the hecks_ai gem to be available.
      #
      # @return [void]
      def mcp
        if options[:domain]
          domain = resolve_domain(options[:domain])
          unless domain
            say "Domain not found: #{options[:domain]}", :red
            return
          end
          require "hecks_ai"
          MCP::DomainServer.new(domain).run
        else
          require "hecks_ai"
          McpServer.new.run
        end
      end
    end
  end
end
