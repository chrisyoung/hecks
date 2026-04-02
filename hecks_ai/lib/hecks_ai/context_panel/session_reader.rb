# Hecks::AI::ContextPanel::SessionReader
#
# Reads the active Claude Code JSONL session file and extracts file paths
# that Claude has interacted with. Returns them deduplicated and sorted by
# most-recent-first.
#
#   reader = SessionReader.new("/Users/me/Projects/hecks")
#   reader.files  # => ["lib/hecks.rb", "spec/hecks_spec.rb"]
#
module Hecks
  module AI
    module ContextPanel
      class SessionReader
        CLAUDE_PROJECTS_DIR = File.join(Dir.home, ".claude", "projects")

        def initialize(project_dir)
          @project_dir = File.expand_path(project_dir)
        end

        def files
          session_file = find_session_file
          return [] unless session_file && File.exist?(session_file)

          extract_files(session_file)
        end

        private

        def find_session_file
          encoded = @project_dir.tr("/", "-")
          project_path = File.join(CLAUDE_PROJECTS_DIR, encoded)

          unless File.directory?(project_path)
            parent_encoded = File.dirname(@project_dir).tr("/", "-")
            project_path = File.join(CLAUDE_PROJECTS_DIR, parent_encoded)
          end

          return nil unless File.directory?(project_path)

          Dir.glob(File.join(project_path, "*.jsonl"))
             .max_by { |f| File.mtime(f) }
        end

        def extract_files(path)
          seen = {}
          counter = 0

          File.foreach(path) do |line|
            line.scan(/"file_path"\s*:\s*"([^"]+)"/) do |match|
              file = match[0]
              counter += 1
              seen[file] = counter
            end
          end

          seen.sort_by { |_, order| -order }
              .map { |file, _| strip_prefix(file) }
        end

        def strip_prefix(file)
          if file.start_with?(@project_dir)
            file.sub("#{@project_dir}/", "")
          elsif file.start_with?(CLAUDE_PROJECTS_DIR)
            file.sub(%r{.*/\.claude/projects/[^/]*/}, "~claude/")
          elsif file.start_with?(Dir.home)
            file.sub(Dir.home, "~")
          else
            file
          end
        end
      end
    end
  end
end
