module Hecks
  module AI
    module Prompts

      # Hecks::AI::Prompts::DomainReview
      #
      # System prompt and tool schema for AI-powered domain model review.
      # The LLM reviews a serialized domain and returns structured feedback
      # on naming, boundaries, missing concepts, and DDD best practices.
      #
      #   DomainReview::SYSTEM_PROMPT
      #   DomainReview::TOOL_SCHEMA
      #
      module DomainReview
        SYSTEM_PROMPT = <<~PROMPT
          You are an expert domain-driven design reviewer. You will receive a
          serialized Hecks domain model (aggregates, commands, events, value
          objects, references, and policies). Analyze it and provide structured
          feedback using the review_domain tool.

          Focus on:
          1. Naming clarity -- are names intention-revealing and ubiquitous?
          2. Aggregate boundaries -- are they properly sized and cohesive?
          3. Missing concepts -- are there implied concepts not yet modeled?
          4. Reference topology -- are there coupling or cycle concerns?
          5. Command/event design -- do they follow DDD conventions?

          Be specific and actionable. Reference aggregate and attribute names.
        PROMPT

        TOOL_SCHEMA = {
          name: "review_domain",
          description: "Submit structured domain review feedback",
          input_schema: {
            type: "object",
            properties: {
              overall_score: {
                type: "integer",
                description: "Domain quality score 1-10"
              },
              strengths: {
                type: "array",
                items: { type: "string" },
                description: "What the domain does well"
              },
              improvements: {
                type: "array",
                items: {
                  type: "object",
                  properties: {
                    area: { type: "string", description: "naming, boundaries, missing_concepts, references, commands" },
                    description: { type: "string" },
                    suggestion: { type: "string" }
                  },
                  required: %w[area description suggestion]
                },
                description: "Specific improvement suggestions"
              },
              missing_concepts: {
                type: "array",
                items: { type: "string" },
                description: "Domain concepts that should be modeled"
              }
            },
            required: %w[overall_score strengths improvements]
          }
        }.freeze
      end
    end
  end
end
