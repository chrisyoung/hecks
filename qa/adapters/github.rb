# frozen_string_literal: true

require "open3"
require "json"

module Hecksagain
  module Adapters
    # THE ISSUE TRACKER, ANSWERED BY `gh`.
    #
    # The `IssueTracker` port's `asks "File"` is the domain wanting an issue
    # raised; this is what answers. It shells out to the GitHub CLI rather
    # than talking to the API directly, for one reason worth stating: `gh`
    # already holds the credential. There is no token in this repository, no
    # secret in a `.world`, and nothing to rotate — whoever is logged in is
    # who files, which is exactly the authority a QA agent should have and no
    # more.
    #
    # WHY IT LIVES HERE AND NOT IN `lib/hecksagain/adapters/driven/`.
    # `Folder#load_library` globs that directory into EVERY registry any boot
    # builds, so an adapter there answers its port for every consumer forever
    # — and `driven.rb`'s own note explains what that costs: two adapters on
    # one port make it permanently ambiguous, because the runtime refuses to
    # choose. The QA spec binds a stub to this same port. So the real one
    # lives with the domain that wants it, loaded by `Folder#load_project`
    # (which is why `qa/adapters/` exists at all), and the two never meet.
    #
    # WHAT IT RETURNS IS THE NEXT COMMAND'S ARGUMENTS. An ask's answer is
    # spread into the answering event, and a policy re-enters `Ticket.Filed`
    # with that payload verbatim — so these keys and shapes are that command's
    # own, `{ number: { value: 43 } }` rather than `43`. That is a real
    # contract between an adapter and a chapter, and it is stated in the port
    # rather than discovered.
    #
    # IT NEVER RAISES ON A REFUSAL. Every way this can fail — no `gh`, not
    # logged in, no such repository, rate limited, issues disabled — is the
    # outside saying no, and the chapter already has a word for that
    # (`refuses "IssueFilingRefused"`). `PortOperationInterpreter#ask` turns
    # any raise into that event, so failing loudly here is correct and
    # nothing needs catching.
    class Github
      def initialize(aggregate: nil, settings: {}, root: nil)
        @settings = settings
        @root     = root
      end

      # `id`, `repository`, `title`, `body` arrive as the port declared them.
      # Everything else the ticket happens to be carrying is ignored — an
      # adapter reads what it needs and is not a second place the payload's
      # shape is enforced.
      def file(repository:, title:, body:, **)
        out, err, status = Open3.capture3(
          "gh", "issue", "create",
          "--repo",  text(repository),
          "--title", text(title),
          "--body",  text(body),
          **(@root ? { chdir: @root } : {})
        )

        raise refusal(err, out, status) unless status.success?

        url = out.to_s[%r{https?://\S+}] or
          raise "gh reported success but printed no issue URL: #{out.to_s.strip.inspect}"

        { number: { value: url[%r{/(\d+)\s*\z}, 1].to_i }, url: { value: url } }
      end

      private

      # A value object arrives as a Hash once `Value.materialize` has been
      # over it; a plain String is what a hand-written caller passes. Both
      # are legitimate and neither is worth making the caller think about.
      def text(field) = field.is_a?(Hash) ? field.values.first.to_s : field.to_s

      # THE MESSAGE IS THE PRODUCT. `gh` says useful things — "could not
      # resolve to a Repository", "HTTP 403", "gh auth login" — and the whole
      # value of recording a refusal is that somebody reading the ledger
      # afterwards knows which. Trimmed only because a ticket's `refusal` is
      # read in a list.
      def refusal(err, out, status)
        said = [err, out].map(&:to_s).map(&:strip).reject(&:empty?).first
        "gh exited #{status.exitstatus}: #{(said || 'no output').lines.first.to_s.strip[0, 300]}"
      end
    end
  end
end
