# frozen_string_literal: true

require_relative "tooling"

module Hecksagain
  module Adapters
    # THE `Toolchain` PORT — everything that reads the repository or keeps it
    # consistent, as against running something over it. What is left here
    # after `Testing` and `Fuzzing` took their own ports is genuinely one
    # role: the chapter's own tooling, none of it swappable for anything
    # (there is no second `bin/ir`), all of it about the shape of the code
    # rather than its behaviour.
    class Toolchain
      include Tooling

      # SHAPE DRIFT, WHICH THIS CHAPTER IS ITSELF UNDER. Adding one attribute
      # to `Bug` closed the ledger until a translation edge was written and
      # audited; an agent that cannot run this cannot tell that wall from a
      # bug in the store.
      def translation_audit(scope:, **) = run("bin/translation_audit", *words(scope))

      def refresh_projections(scope:, **) = run("bin/project", *words(scope))

      # THE SHAPE, AND THE MANUAL — the two reads that answer the failure the
      # interview named first: an `as:` that did not alias, a query whose read
      # model silently drifted. Both are visible in the canonical IR and in
      # neither the source nor the output of any test.
      #
      # `keep: :head` because both are documents. Truncating IR from the end
      # hands back JSON that will not parse.
      def structure(scope:, **) = run("bin/ir", *words(scope), keep: :head)
      def read_docs(scope:, **) = run("bin/docs", *words(scope), keep: :head)

      # THE ESCAPE HATCH, AND IT IS DELIBERATELY NARROW. "Run a one-off script
      # to discover bugs" is a real story, and an agent with no shell needs
      # SOME way to run the throwaway reproduction it just wrote. But an
      # unconstrained "run this string" would make every other operation on
      # every one of these ports decorative — why ask `ModelCheck` when you
      # can ask for a shell? — and the doors are the point.
      #
      # SO IT RUNS A FILE, NOT A COMMAND LINE. `scope` is a path; the words
      # after it are its arguments; nothing is passed to a shell, so no quote,
      # semicolon or backtick in an argument changes what runs. A script the
      # agent wants run is one it first had to write, through `WriteTest`,
      # which is itself on the record.
      def run_script(scope:, **)
        path, *rest = words(scope)
        raise "no such script: #{path}" unless File.exist?(File.expand_path(path.to_s, @root))

        run(*ruby_prefix(path), path, *rest)
      end

      private

      # A `.rb` FILE IS RUN BY RUBY WHETHER OR NOT IT IS EXECUTABLE, because
      # "I wrote a script and it said Permission denied" is a refusal that
      # teaches nothing about the bug being chased.
      def ruby_prefix(path) = path.to_s.end_with?(".rb") ? ["bundle", "exec", "ruby"] : []
    end
  end
end
