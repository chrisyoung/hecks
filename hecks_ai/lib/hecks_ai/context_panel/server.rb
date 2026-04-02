# Hecks::AI::ContextPanel::Server
#
# WEBrick server that serves a browser-based context panel showing files
# Claude Code is working with. Reads Claude's JSONL session for file paths
# and exposes a POST endpoint for direct context updates.
#
#   Server.new(project_dir: Dir.pwd, port: 3001).run
#
require "webrick"
require "json"
require_relative "session_reader"

module Hecks
  module AI
    module ContextPanel
      class Server
        VIEWS_DIR = File.join(__dir__, "views")

        def initialize(project_dir: Dir.pwd, port: 3001)
          @project_dir = project_dir
          @port = port
          @reader = SessionReader.new(project_dir)
          @pushed_context = nil
        end

        def run
          server = WEBrick::HTTPServer.new(
            Port: @port,
            Logger: WEBrick::Log.new($stderr, WEBrick::Log::WARN),
            AccessLog: []
          )
          server.mount_proc("/") { |req, res| handle(req, res) }
          trap("INT") { server.shutdown }
          puts "Context panel: http://localhost:#{@port}"
          server.start
        end

        private

        def handle(req, res)
          case [req.request_method, req.path]
          when ["GET",  "/"]      then serve_panel(res)
          when ["GET",  "/files"] then serve_files(res)
          when ["POST", "/context"] then receive_context(req, res)
          else
            res.status = 404
            res.body = "Not found"
          end
        end

        def serve_panel(res)
          res.content_type = "text/html"
          res["Cache-Control"] = "no-cache, no-store"
          res.body = File.read(File.join(VIEWS_DIR, "panel.html"))
        end

        def serve_files(res)
          files = @pushed_context || @reader.files
          res.content_type = "application/json"
          res["Cache-Control"] = "no-cache, no-store"
          res.body = JSON.generate(files: files)
        end

        def receive_context(req, res)
          data = JSON.parse(req.body)
          @pushed_context = data["files"] if data["files"]
          res.content_type = "application/json"
          res.body = JSON.generate(ok: true)
        rescue JSON::ParserError => e
          res.status = 400
          res.content_type = "application/json"
          res.body = JSON.generate(error: e.message)
        end
      end
    end
  end
end
