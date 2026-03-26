# Hecks::CLI::ConflictHandler
#
# Mixin for CLI generators that write files. When a target file already
# exists, shows a unified diff and offers interactive resolution. Supports
# --force to overwrite without prompting. Uses system `diff -u` for real
# unified diffs with proper insertion/deletion handling.
#
#   class Domain < Thor
#     include ConflictHandler
#
#     def some_generator
#       write_or_diff("app.rb", new_content)
#     end
#   end
#
module Hecks
  class CLI < Thor
    module ConflictHandler
      # Write a file, showing a diff if it already exists with different content.
      # Checks for --force option on the current Thor command.
      # Returns true if the file was written, false if skipped.
      def write_or_diff(path, new_content)
        unless File.exist?(path)
          dir = File.dirname(path)
          FileUtils.mkdir_p(dir) unless dir == "."
          File.write(path, new_content)
          say "Created #{path}", :green
          return true
        end

        existing = File.read(path)
        if existing == new_content
          say "#{path} is already up to date", :green
          return false
        end

        force = options[:force] rescue false
        if force
          File.write(path, new_content)
          say "Overwrote #{path}", :green
          return true
        end

        say "#{path} differs:", :yellow
        show_diff(existing, new_content, path)

        if $stdin.tty?
          resolve_interactively(path, new_content)
        else
          say "Run with --force to overwrite, or apply manually.", :yellow
          false
        end
      end

      private

      def show_diff(old_content, new_content, path)
        require "tempfile"
        old_file = Tempfile.new(["old", File.extname(path)])
        new_file = Tempfile.new(["new", File.extname(path)])
        old_file.write(old_content); old_file.close
        new_file.write(new_content); new_file.close

        diff = `diff -u "#{old_file.path}" "#{new_file.path}" 2>/dev/null`
        # Replace temp paths with meaningful labels
        diff = diff.sub(/^---.*$/, "--- #{path} (existing)")
                   .sub(/^\+\+\+.*$/, "+++ #{path} (generated)")
        diff.each_line do |line|
          case line[0]
          when "-" then say line.chomp, :red
          when "+" then say line.chomp, :green
          when "@" then say line.chomp, :cyan
          else say line.chomp
          end
        end
      ensure
        old_file&.unlink
        new_file&.unlink
      end

      def resolve_interactively(path, new_content)
        loop do
          answer = ask("  [y]es overwrite / [n]o skip / [d]iff again / [e]dit in $EDITOR: ")
          case answer.strip.downcase
          when "y", "yes"
            File.write(path, new_content)
            say "Updated #{path}", :green
            return true
          when "n", "no", ""
            say "Skipped #{path}", :yellow
            return false
          when "d", "diff"
            show_diff(File.read(path), new_content, path)
          when "e", "edit"
            open_in_editor(path, new_content)
            return true
          end
        end
      end

      def open_in_editor(path, new_content)
        # Write generated version to a temp file for reference
        require "tempfile"
        ref = Tempfile.new(["generated", File.extname(path)])
        ref.write(new_content); ref.close
        say "Generated version saved to: #{ref.path}", :cyan
        editor = ENV["EDITOR"] || "vim"
        system("#{editor} #{path}")
        say "Kept your edits in #{path}", :green
      ensure
        ref&.unlink
      end
    end
  end
end
