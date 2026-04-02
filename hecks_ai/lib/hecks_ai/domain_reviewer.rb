# Hecks::AI::DomainReviewer
#
# Sends a serialized Domain IR to the Anthropic LLM and returns structured
# DDD review findings. Uses tool_use to force structured output matching the
# review schema -- no free-form text, no parsing failures.
#
# Gracefully degrades when ANTHROPIC_API_KEY is not set, returning a stub
# review that tells the user to configure their API key.
#
#   domain = Hecks.last_domain
#   review = Hecks::AI::DomainReviewer.new(domain).call
#   review[:overall_score]  # => 7
#   review[:findings]       # => [{ target: "Order", severity: "warning", ... }]
#
module Hecks
  module AI
    class DomainReviewer
      require "net/http"
      require "uri"
      require "json"

      API_URL    = "https://api.anthropic.com/v1/messages"
      MODEL      = "claude-opus-4-5"
      MAX_TOKENS = 4096

      # @param domain [Hecks::DomainModel::Structure::Domain] the domain to review
      # @param api_key [String, nil] Anthropic API key (defaults to ENV)
      # @param model [String] model ID override
      def initialize(domain, api_key: ENV["ANTHROPIC_API_KEY"], model: MODEL)
        @domain  = domain
        @api_key = api_key
        @model   = model
      end

      # Performs the review. Returns a Hash with :overall_score, :summary, :findings.
      # Degrades gracefully without an API key.
      #
      # @return [Hash] structured review result
      def call
        return unavailable_review unless @api_key && !@api_key.strip.empty?

        body     = build_request
        response = post(body)
        extract_tool_result(response)
      end

      private

      def serialize_domain
        require_relative "domain_serializer"
        Hecks::MCP::DomainSerializer.call(@domain)
      end

      def build_request
        {
          model: @model,
          max_tokens: MAX_TOKENS,
          system: Hecks::AI::Prompts::DomainReview::SYSTEM_PROMPT,
          tools: [Hecks::AI::Prompts::DomainReview::TOOL_SCHEMA],
          tool_choice: { type: "tool", name: "review_domain" },
          messages: [
            { role: "user", content: "Review this domain model:\n\n#{JSON.generate(serialize_domain)}" }
          ]
        }
      end

      def post(body)
        uri  = URI.parse(API_URL)
        http = Net::HTTP.new(uri.host, uri.port)
        http.use_ssl = true

        request = Net::HTTP::Post.new(uri.path)
        request["x-api-key"]        = @api_key
        request["anthropic-version"] = "2023-06-01"
        request["content-type"]      = "application/json"
        request.body = JSON.generate(body)

        response = http.request(request)
        raise "Anthropic API error #{response.code}: #{response.body}" unless response.code == "200"

        JSON.parse(response.body, symbolize_names: true)
      end

      def extract_tool_result(response)
        content  = response[:content] || []
        tool_use = content.find { |block| block[:type] == "tool_use" }
        raise "No tool_use block in response" unless tool_use

        input = tool_use[:input]
        raise "Empty tool input in response" unless input

        input
      end

      def unavailable_review
        {
          overall_score: 0,
          summary: "AI review unavailable -- set ANTHROPIC_API_KEY to enable.",
          findings: []
        }
      end
    end
  end
end
