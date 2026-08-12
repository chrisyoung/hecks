require "json"
require_relative "../quality_control/ledger"

module Hecksagain
  # THE DEVELOPMENT MCP — THIS REPOSITORY'S OWN TOOLS, SPOKEN AS MCP.
  #
  # An agent doing QA on hecksagain has a workflow (`qa/SOP.md`) and now a
  # model of it (`qa/bluebook/quality_control.bluebook`). What it did not
  # have is a way to USE the model without writing Ruby: an agent that has
  # to compose a `Hecks.boot` and a dispatch string to record a bug will
  # keep editing markdown instead, which is what the model exists to stop.
  #
  # NAMED `hecksagain_development_mcp`, not `quality_control_mcp` — quality
  # control is the first practice to get tools here and will not be the
  # last. Every tool it serves today is prefixed `qc_`; a second practice
  # adds a second prefix and no new server.
  #
  # STDIO JSON-RPC, HAND-WRITTEN, NO DEPENDENCY. The protocol surface an MCP
  # server actually needs is four methods — `initialize`, the
  # `notifications/initialized` acknowledgement, `tools/list` and
  # `tools/call`. Adding a gem to this repository's Gemfile so an
  # optional development tool can speak forty lines of JSON-RPC would make
  # every consumer of the gem carry it. See `hecksagain.gemspec`.
  #
  # ONE BOOT, LAZILY, FOR THE LIFE OF THE PROCESS. `Ledger.open` boots a
  # runtime and opens Heki files; doing that per tool call would reopen them
  # dozens of times a session. Lazy because an editor may start this server
  # and never call a tool, and a boot that raises at startup is a server
  # that looks broken rather than one that has nothing to do yet.
  module DevelopmentMcp
    PROTOCOL_VERSION = "2024-11-05".freeze

    class Server
      def initialize(input: $stdin, output: $stdout, root: nil)
        @input  = input
        @output = output
        @root   = root
        @output.sync = true
      end

      def run
        while (line = @input.gets)
          line = line.strip
          next if line.empty?

          begin
            request = JSON.parse(line)
          rescue JSON::ParserError => e
            respond(nil, error: { code: -32_700, message: "parse error: #{e.message}" })
            next
          end

          handle(request)
        end
      end

      private

      def ledger = @ledger ||= QualityControl::Ledger.open(**(@root ? { root: @root } : {}))

      def handle(request)
        id     = request["id"]
        method = request["method"]

        # A NOTIFICATION HAS NO ID AND TAKES NO ANSWER. Replying to one is a
        # protocol violation some clients treat as fatal.
        return if id.nil?

        case method
        when "initialize"  then respond(id, result: initialize_result(request))
        when "tools/list"  then respond(id, result: { "tools" => Tools.descriptors })
        when "tools/call"  then respond(id, result: call_tool(request["params"] || {}))
        when "ping"        then respond(id, result: {})
        else
          respond(id, error: { code: -32_601, message: "unknown method #{method.inspect}" })
        end
      rescue StandardError => e
        # THE SERVER ITSELF FAILING, as distinct from a tool refusing —
        # see `call_tool` for the other half of that split.
        respond(id, error: { code: -32_603, message: "#{e.class}: #{e.message}" })
      end

      # THE CLIENT'S OWN VERSION, ECHOED WHEN IT NAMES ONE. A server that
      # insists on its own version fails a handshake with a newer client
      # for no reason; the four methods above have not changed across any
      # of them.
      def initialize_result(request)
        wanted = request.dig("params", "protocolVersion")
        {
          "protocolVersion" => wanted.is_a?(String) && !wanted.empty? ? wanted : PROTOCOL_VERSION,
          "capabilities"    => { "tools" => {} },
          "serverInfo"      => { "name" => "hecksagain_development_mcp",
                                 "version" => Hecksagain::VERSION }
        }
      end

      # A DOMAIN REFUSAL IS A TOOL RESULT, NOT A TRANSPORT ERROR.
      #
      # `isError: true` with the refusal wording in the content is what puts
      # the language's own sentence — "Investigate refused — status is
      # \"found\", and Investigate moves it only from \"reproduced\"" — in
      # front of the agent, which is the single most useful thing this
      # server transmits. A JSON-RPC error would surface as a tool failure
      # with the message buried, and some clients hide it entirely.
      def call_tool(params)
        name = params["name"].to_s
        args = symbolize(params["arguments"] || {})
        text = Tools.call(ledger, name, args)
        { "content" => [{ "type" => "text", "text" => text }] }
      rescue *Runtime::DOMAIN_REFUSALS => e
        { "content" => [{ "type" => "text", "text" => "REFUSED — #{e.message}" }], "isError" => true }
      rescue ArgumentError, KeyError => e
        { "content" => [{ "type" => "text", "text" => "BAD REQUEST — #{e.message}" }], "isError" => true }
      rescue StandardError => e
        { "content" => [{ "type" => "text", "text" => "#{e.class}: #{e.message}" }], "isError" => true }
      end

      def symbolize(hash) = hash.to_h { |k, v| [k.to_sym, v] }

      def respond(id, result: nil, error: nil)
        payload = { "jsonrpc" => "2.0", "id" => id }
        payload[error ? "error" : "result"] = error || result
        @output.puts(JSON.generate(payload))
      end
    end
  end
end

require_relative "tools"
