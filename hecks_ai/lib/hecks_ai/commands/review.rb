# Hecks::CLI -- review command
#
# AI-powered domain model review. Sends the domain to an LLM for
# structured DDD feedback. Falls back to local heuristic review
# when no API key is available.
#
#   hecks review
#   hecks review --domain path/to/domain
#   hecks review --format json
#
Hecks::CLI.register_command(:review, "AI-powered domain model review",
  options: {
    domain: { type: :string, desc: "Domain gem name or path" },
    format: { type: :string, desc: "Output format: text (default) or json" }
  }
) do
  domain = resolve_domain_option
  return unless domain

  reviewer = Hecks::AI::DomainReviewer.new(domain)
  review = reviewer.review

  if options[:format] == "json"
    require "json"
    say JSON.pretty_generate(review)
    next
  end

  source = review[:source] == "local" ? " (local -- set ANTHROPIC_API_KEY for AI review)" : ""
  say "Domain Review: #{domain.name}#{source}", :bold
  say "Score: #{review[:overall_score]}/10"
  say ""

  if review[:strengths]&.any?
    say "Strengths:", :green
    review[:strengths].each { |s| say "  + #{s}" }
    say ""
  end

  if review[:improvements]&.any?
    say "Improvements:", :yellow
    review[:improvements].each do |imp|
      imp = imp.transform_keys(&:to_sym) if imp.is_a?(Hash)
      say "  [#{imp[:area]}] #{imp[:description]}"
      say "    -> #{imp[:suggestion]}" if imp[:suggestion] && !imp[:suggestion].empty?
    end
  end

  if review[:missing_concepts]&.any?
    say ""
    say "Missing Concepts:", :cyan
    review[:missing_concepts].each { |c| say "  ? #{c}" }
  end
end
