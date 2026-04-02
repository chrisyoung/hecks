# Hecks::AI::IDE::Server
#
# Browser-based IDE that streams a Claude Code terminal over WebSocket
# alongside a live context panel. Runs WEBrick for HTTP and a raw
# TCPServer for the terminal WebSocket on port+1.
#
#   Server.new(project_dir: Dir.pwd, port: 3001).run
#
require "webrick"
require "json"
require_relative "websocket"
require_relative "terminal"
require_relative "../context_panel/session_reader"

module Hecks
  module AI
    module IDE
      class Server
        VIEWS_DIR = File.join(__dir__, "views")

        def initialize(project_dir: Dir.pwd, port: 3001)
          @project_dir = project_dir
          @port = port
          @ws_port = port + 1
          @reader = ContextPanel::SessionReader.new(project_dir)
        end

        def run
          start_terminal_server
          start_http_server
        end

        private

        def start_terminal_server
          Thread.new do
            server = TCPServer.new("127.0.0.1", @ws_port)
            loop { handle_terminal_client(server) }
          end
        end

        def handle_terminal_client(server)
          ws = WebSocket.accept(server)
          return unless ws

          terminal = Terminal.new("claude --dangerously-skip-permissions")

          reader_thread = Thread.new do
            while terminal.alive?
              data = terminal.read
              ws.write(data) if data && !ws.closed?
            end
            ws.write("\r\n[Process exited]\r\n") rescue nil
          end

          while (msg = ws.read)
            break if msg == :close
            next  if msg == :ping

            if msg.start_with?("{")
              handle_json_message(msg, terminal)
            else
              terminal.write(msg)
            end
          end

          reader_thread.kill
          terminal.close
          ws.close
        rescue => e
          $stderr.puts "Terminal session error: #{e.message}"
        end

        def handle_json_message(msg, terminal)
          data = JSON.parse(msg)
          terminal.resize(data["cols"], data["rows"]) if data["type"] == "resize"
        rescue JSON::ParserError
          terminal.write(msg)
        end

        def start_http_server
          reader = @reader
          ws_port = @ws_port

          http = WEBrick::HTTPServer.new(
            Port: @port,
            Logger: WEBrick::Log.new($stderr, WEBrick::Log::WARN),
            AccessLog: []
          )

          http.mount_proc("/") do |req, res|
            route_request(req, res, reader, ws_port)
          end

          trap("INT") { http.shutdown }

          Thread.new do
            sleep 0.5
            open_browser("http://localhost:#{@port}")
          end

          puts "Hecks IDE: http://localhost:#{@port}"
          puts "Terminal WS: ws://localhost:#{ws_port}"
          http.start
        end

        def route_request(req, res, reader, ws_port)
          case [req.request_method, req.path]
          when ["GET", "/"]
            res.content_type = "text/html"
            html = File.read(File.join(VIEWS_DIR, "ide.html"))
            res.body = html.gsub("{{WS_PORT}}", ws_port.to_s)
          when ["GET", "/files"]
            res.content_type = "application/json"
            res["Cache-Control"] = "no-cache, no-store"
            res.body = JSON.generate(files: reader.files)
          else
            res.status = 404
            res.body = "Not found"
          end
        end

        def open_browser(url)
          system("open #{url} 2>/dev/null") ||
            system("xdg-open #{url} 2>/dev/null")
        end
      end
    end
  end
end
