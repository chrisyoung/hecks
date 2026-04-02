module Hecks
  module AI

    # Hecks::AI::DomainReviewer
    #
    # AI-powered domain model review. Serializes the domain, sends it to
    # the Anthropic API, and returns structured feedback. Degrades gracefully
    # when no API key is available by returning a canned local review.
    #
    #   reviewer = DomainReviewer.new(domain)
    #   review = reviewer.review
    #   review[:overall_score]   # => 7
    #   review[:improvements]    # => [{area: "naming", ...}]
    #
    class DomainReviewer
      # @param domain [Hecks::DomainModel::Structure::Domain] the domain to review
      # @param api_key [String, nil] Anthropic API key (uses ENV if nil)
      def initialize(domain, api_key: nil)
        @domain = domain
        @api_key = api_key || ENV["ANTHROPIC_API_KEY"]
      end

      # Run the domain review. Uses AI when API key is available,
      # falls back to local heuristic review otherwise.
      #
      # @return [Hash] structured review with :overall_score, :strengths,
      #   :improvements, and optionally :missing_concepts
      def review
        if @api_key
          ai_review
        else
          local_review
        end
      end

      private

      def ai_review
        serialized = serialize_domain
        client = Hecks::AI::LlmClient.new(api_key: @api_key)

        body = {
          model: "claude-sonnet-4-20250514",
          max_tokens: 4096,
          system: Prompts::DomainReview::SYSTEM_PROMPT,
          tools: [Prompts::DomainReview::TOOL_SCHEMA],
          tool_choice: { type: "tool", name: "review_domain" },
          messages: [
            { role: "user", content: "Review this domain:\n\n#{JSON.generate(serialized)}" }
          ]
        }

        response = client_post(body)
        extract_review(response)
      end

      def local_review
        validator = Hecks::Validator.new(@domain)
        validator.valid?

        {
          overall_score: calculate_score(validator),
          strengths: detect_strengths,
          improvements: validator.warnings.map do |w|
            { area: "validation", description: w.to_s, suggestion: w.respond_to?(:hint) ? w.hint.to_s : "" }
          end,
          source: "local"
        }
      end

      def calculate_score(validator)
        base = 10
        base -= [validator.errors.size * 2, 5].min
        base -= [validator.warnings.size, 3].min
        [base, 1].max
      end

      def detect_strengths
        strengths = []
        strengths << "Domain has #{@domain.aggregates.size} well-defined aggregates" if @domain.aggregates.size >= 2
        strengths << "All aggregates have commands" if @domain.aggregates.all? { |a| a.commands.any? }
        strengths << "Uses value objects for composition" if @domain.aggregates.any? { |a| a.value_objects.any? }
        strengths << "Includes lifecycle state management" if @domain.aggregates.any? { |a| a.lifecycle }
        strengths << "Has reactive policies for decoupling" if @domain.aggregates.any? { |a| a.policies.any? }
        strengths << "Domain model is well-structured" if strengths.empty?
        strengths
      end

      def client_post(body)
        require "net/http"
        require "uri"
        require "json"

        uri = URI.parse("https://api.anthropic.com/v1/messages")
        http = Net::HTTP.new(uri.host, uri.port)
        http.use_ssl = true

        request = Net::HTTP::Post.new(uri.path)
        request["x-api-key"] = @api_key
        request["anthropic-version"] = "2023-06-01"
        request["content-type"] = "application/json"
        request.body = JSON.generate(body)

        response = http.request(request)
        raise "API error #{response.code}: #{response.body}" unless response.code == "200"
        JSON.parse(response.body, symbolize_names: true)
      end

      def serialize_domain
        {
          name: @domain.name,
          aggregates: @domain.aggregates.map do |agg|
            {
              name: agg.name,
              attributes: agg.attributes.map { |a| { name: a.name.to_s, type: a.type.to_s } },
              commands: agg.commands.map { |c| c.name },
              events: agg.events.map { |e| e.name },
              value_objects: agg.value_objects.map { |vo| vo.name },
              references: (agg.references || []).map { |r| r.type.to_s }
            }
          end
        }
      end

      def extract_review(response)
        content = response[:content] || []
        tool_use = content.find { |block| block[:type] == "tool_use" }
        raise "No review in response" unless tool_use
        tool_use[:input]
      end
    end
  end
end
