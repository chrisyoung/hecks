# Hecks::McpServer
#
# MCP (Model Context Protocol) server that exposes the Hecks Session API
# as tools for AI agents. Registers five tool groups (SessionTools,
# AggregateTools, InspectTools, BuildTools, PlayTools) and runs over
# stdio transport. Provides shared helpers for type resolution and
# output capture used by all tool modules.
#
#   hecks domain mcp    # starts the server on stdio
#
require "mcp"
require_relative "session_tools"
require_relative "aggregate_tools"
require_relative "inspect_tools"
require_relative "build_tools"
require_relative "play_tools"

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
      require "mcp/server/transports/stdio_transport"
      ::MCP::Server::Transports::StdioTransport.new(@server).open
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
