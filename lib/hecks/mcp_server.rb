# Hecks::McpServer
#
# MCP server that exposes the Hecks Session API as tools for AI agents.
# Like `hecks console` but for AI — agents build and play with domains
# through tool calls instead of a REPL.
#
#   hecks mcp    # starts the server on stdio
#
require "mcp"
require_relative "mcp/session_tools"
require_relative "mcp/aggregate_tools"
require_relative "mcp/inspect_tools"
require_relative "mcp/build_tools"
require_relative "mcp/play_tools"

module Hecks
  class McpServer
    attr_accessor :session

    def initialize
      @session = nil
      @server = ::MCP::Server.new(name: "hecks", version: Hecks::VERSION)
      Hecks::MCP::SessionTools.register(@server, self)
      Hecks::MCP::AggregateTools.register(@server, self)
      Hecks::MCP::InspectTools.register(@server, self)
      Hecks::MCP::BuildTools.register(@server, self)
      Hecks::MCP::PlayTools.register(@server, self)
    end

    def run
      transport = ::MCP::Transport::Stdio.new(@server)
      transport.open
    end

    def ensure_session!
      raise "No session. Call create_session first." unless @session
    end

    def resolve_type(type_str)
      case type_str
      when "String" then String
      when "Integer" then Integer
      when "Float" then Float
      when /^reference_to\((.+)\)$/ then { reference: $1.delete('"') }
      when /^list_of\((.+)\)$/ then { list: $1.delete('"') }
      else String
      end
    end

    def capture_output
      output = StringIO.new
      $stdout = output
      yield
      $stdout = STDOUT
      output.string
    rescue => e
      $stdout = STDOUT
      "Error: #{e.message}"
    end
  end
end
