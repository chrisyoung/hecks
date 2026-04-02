# Hecks::AI::Commands::Review
#
# CLI command: run an AI-powered DDD review of a domain model.
# Reads ANTHROPIC_API_KEY from ENV, serializes the domain IR, sends to the LLM,
# and prints structured findings. Degrades gracefully without an API key.
#
#   hecks review                         # review the local Bluebook domain
#   hecks review --domain path/to/domain # explicit domain path
#   hecks review --format json           # raw JSON output for tooling
#
Hecks::CLI.register_command(:review, "AI-powered DDD review of a domain model",
  options: {
    domain: { type: :string, desc: "Domain gem name or path" },
    format: { type: :string, desc: "Output format: text (default) or json" },
    model:  { type: :string, desc: "Anthropic model (default: claude-opus-4-5)" }
  }
) do
  require "hecks_ai"
  require_relative "../domain_reviewer"
  require_relative "../prompts/domain_review"
  require_relative "../domain_serializer"

  domain = resolve_domain_option
  next unless domain

  reviewer_opts = {}
  reviewer_opts[:model] = options[:model] if options[:model]

  say "Reviewing domain: #{domain.name}..."

  review = Hecks::AI::DomainReviewer.new(domain, **reviewer_opts).call

  if options[:format] == "json"
    require "json"
    say JSON.pretty_generate(review)
    next
  end

  print_review(review)
end

def print_review(review)
  score   = review[:overall_score] || review["overall_score"] || 0
  summary = review[:summary]       || review["summary"] || ""
  findings = review[:findings]     || review["findings"] || []

  say ""
  color = score >= 7 ? :green : score >= 4 ? :yellow : :red
  say "Score: #{score}/10", color
  say summary
  say ""

  if findings.empty?
    say "No findings.", :green
    return
  end

  findings.each do |f|
    sev = f[:severity] || f["severity"]
    sev_color = case sev
    when "critical" then :red
    when "warning"  then :yellow
    else :cyan
    end

    target = f[:target]         || f["target"]
    cat    = f[:category]       || f["category"]
    msg    = f[:message]        || f["message"]
    rec    = f[:recommendation] || f["recommendation"]

    say "  [#{sev.upcase}] #{target} (#{cat})", sev_color
    say "    #{msg}"
    say "    => #{rec}", :white
    say ""
  end
end
