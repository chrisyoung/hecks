# frozen_string_literal: true

require "fileutils"
require_relative "tooling"

module Hecksagain
  module Adapters
    # THE `Testing` PORT, ANSWERED BY RSPEC.
    #
    # The port is named for the job, not the program — `Testing`, answered
    # today by rspec and tomorrow by whatever else, with the chapter unchanged
    # either way. That is not a hypothetical: the four operations here are
    # exactly what a QA agent needs from ANY test runner, and none of them
    # mentions rspec in the bluebook.
    class Rspec
      include Tooling

      # `scope` is handed to the runner verbatim, which is why "the whole
      # file" and "line 42" need one operation rather than two:
      # `spec/bug_spec.rb:42` is already the thing rspec takes.
      def run_specs(scope:, **) = run("bundle", "exec", "rspec", *words(scope))

      def smoke_test(scope:, **) = run("bin/smoke_test", *words(scope))

      # THE ONE THAT WRITES, and it belongs on this port rather than beside
      # the read-only tools because writing a failing test is part of testing,
      # not part of inspecting. `Bug.Log` refuses a bug with no
      # `demonstration`, so this is the step that earns the right to log one.
      #
      # IT REFUSES TO OVERWRITE. A failing test written over an existing file
      # destroys evidence — possibly the evidence for a different bug — and
      # the agent that did it would see a clean answer. Refusing costs a
      # rename; not refusing costs a spec nobody can get back.
      def write_test(scope:, source:, **)
        path = File.expand_path(text(scope), @root)
        raise "#{text(scope)} already exists — write the failing test somewhere new, or delete that one deliberately" if File.exist?(path)

        FileUtils.mkdir_p(File.dirname(path))
        File.write(path, text(source))
        answer("wrote #{text(scope)} (#{text(source).lines.size} lines)", 0)
      end

      # WHICH COMMIT INTRODUCED IT — the one question no amount of running the
      # suite at HEAD can answer, and the reason "investigate a bug" is a
      # story of its own. It sits on the testing port because a bisect IS a
      # test run, repeated: the runner is what decides each step good or bad.
      #
      # THE WORKING TREE IS NOT TOUCHED. `git bisect` moves HEAD, and an agent
      # sharing this checkout with a person would find their tree detached
      # mid-edit. So the bisect happens in a throwaway worktree that is
      # removed however this ends.
      def bisect(scope:, since:, **)
        arena = File.expand_path(".bisect-#{Process.pid}", @root)
        run("git", "worktree", "add", "--detach", arena, "HEAD")
        begin
          run("git", "-C", arena, "bisect", "start", "HEAD", text(since))
          run("git", "-C", arena, "bisect", "run", "bundle", "exec", "rspec", *words(scope))
        ensure
          run("git", "-C", arena, "bisect", "reset")
          run("git", "worktree", "remove", "--force", arena)
        end
      end
    end
  end
end
