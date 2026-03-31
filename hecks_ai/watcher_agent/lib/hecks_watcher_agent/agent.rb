# HecksWatcherAgent::Agent
#
# Reads watcher log, parses issues, and creates PRs to fix them.
# Simple fixes (autoloads, skeleton specs) are applied directly.
# Complex fixes (file extraction, doc updates) delegate to Claude Code.
#
#   HecksWatcherAgent::Agent.new(project_root: Dir.pwd).call
#
require "fileutils"

module HecksWatcherAgent
  class Agent
    def initialize(project_root:)
      @project_root = project_root
      @fixes = []
    end

    def call
      issues = parse_log
      return puts("No watcher issues found.") if issues.empty?

      puts "Found #{issues.size} watcher issue(s):"
      issues.each { |i| puts "  [#{i[:type]}] #{i[:message]}" }

      branch = create_branch
      issues.each { |issue| fix(issue) }

      if @fixes.any?
        commit_and_pr(branch)
      else
        puts "No auto-fixable issues. Cleaning up branch."
        system("git", "checkout", "-", chdir: @project_root)
        system("git", "branch", "-D", branch, chdir: @project_root)
      end
    end

    private

    def parse_log
      log_file = File.join(@project_root, "tmp", "watcher.log")
      return [] unless File.exist?(log_file)

      content = File.read(log_file).strip
      return [] if content.empty?

      issues = []
      current_type = nil

      content.each_line do |line|
        line = line.strip
        case line
        when /files approaching.*limit/i then current_type = :file_size
        when /New files possibly missing from autoloads/i then current_type = :autoloads
        when /New lib files without specs/i then current_type = :spec_coverage
        when /Doc reminders/i then current_type = :doc_reminder
        when /BLOCKED.*cross.*require/i then current_type = :cross_require
        when /^\s*$/, /^Check / then next
        else
          issues << { type: current_type, message: line } if current_type && line.length > 2
        end
      end

      issues
    end

    def create_branch
      branch = "watcher-fixes-#{Time.now.strftime('%Y%m%d-%H%M%S')}"
      system("git", "checkout", "-b", branch, chdir: @project_root)
      branch
    end

    def fix(issue)
      case issue[:type]
      when :autoloads then fix_autoloads(issue)
      when :spec_coverage then fix_spec_coverage(issue)
      when :file_size then fix_with_claude(issue)
      when :doc_reminder then fix_with_claude(issue)
      when :cross_require then skip(issue, "needs architectural decision")
      end
    end

    def fix_autoloads(issue)
      match = issue[:message].match(/(\w+) \((.+)\)/)
      return unless match

      class_name, file_path = match[1], match[2]
      autoloads_path = File.join(@project_root, "hecksties/lib/hecks/autoloads.rb")
      return unless File.exist?(autoloads_path)

      content = File.read(autoloads_path)
      return if content.include?(":#{class_name}")

      require_path = file_path.sub(%r{^[^/]+/lib/}, "").sub(/\.rb$/, "")
      entry = "  autoload :#{class_name}, \"#{require_path}\""
      content = content.sub(/^end\s*\z/m, "#{entry}\nend\n")
      File.write(autoloads_path, content)

      @fixes << "Added autoload for #{class_name}"
      puts "  Fixed: autoload #{class_name}"
    end

    def fix_spec_coverage(issue)
      match = issue[:message].match(/(.+\.rb)\s+→\s+expected\s+(.+)/)
      return unless match

      lib_path, spec_path = match[1], match[2]
      full_spec = File.join(@project_root, spec_path)
      return if File.exist?(full_spec)

      basename = File.basename(lib_path, ".rb")
      class_name = basename.split("_").map(&:capitalize).join

      FileUtils.mkdir_p(File.dirname(full_spec))
      File.write(full_spec, <<~RUBY)
        require "spec_helper"

        RSpec.describe #{class_name} do
          pending "add specs"
        end
      RUBY

      @fixes << "Generated skeleton spec: #{spec_path}"
      puts "  Fixed: skeleton spec for #{class_name}"
    end

    def fix_with_claude(issue)
      prompt = case issue[:type]
      when :file_size
        "Fix this watcher issue by extracting modules to reduce file size: #{issue[:message]}. Keep files under 200 lines of code."
      when :doc_reminder
        "Fix this watcher issue by updating documentation: #{issue[:message]}"
      end

      puts "  Delegating to Claude Code: #{issue[:message]}"
      result = system("claude", "-p", prompt, "--allowedTools", "Read,Edit,Write,Glob,Grep", chdir: @project_root)

      if result
        @fixes << "Claude fixed: #{issue[:message]}"
      else
        puts "  Claude could not fix: #{issue[:message]}"
      end
    end

    def skip(issue, reason)
      puts "  Skipped [#{issue[:type]}]: #{reason}"
    end

    def commit_and_pr(branch)
      Dir.chdir(@project_root) do
        system("git", "add", "-A")
        system("git", "commit", "-m", <<~MSG.strip)
          Auto-fix watcher issues

          #{@fixes.join("\n")}

          Co-Authored-By: HecksWatcherAgent <noreply@hecks.dev>
        MSG
        system("git", "push", "-u", "origin", branch)
        system("gh", "pr", "create",
          "--title", "Fix #{@fixes.size} watcher issue(s)",
          "--body", "## Watcher Agent Auto-Fix\n\n#{@fixes.map { |f| "- #{f}" }.join("\n")}\n\n🤖 Generated by HecksWatcherAgent")
      end
    end
  end
end
