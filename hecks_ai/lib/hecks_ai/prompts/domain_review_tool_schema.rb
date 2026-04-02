# Hecks::AI::Prompts::DomainReviewToolSchema
#
# Anthropic tool_use schema for the review_domain tool. Defines the JSON
# structure the LLM must return when reviewing a domain model.
#
# Separated from DomainReview to keep file sizes within limits.
#
#   Hecks::AI::Prompts::DomainReviewToolSchema::SCHEMA  # => Hash
#
module Hecks
  module AI
    module Prompts
      module DomainReviewToolSchema
        FINDING_ITEM = {
          type: "object",
          required: %w[target category severity message recommendation],
          properties: {
            target:         { type: "string", description: "Aggregate or element name this applies to" },
            category:       { type: "string", description: "Review category: boundaries, commands, value_objects, naming, references, policies, missing_patterns" },
            severity:       { type: "string", enum: %w[critical warning suggestion] },
            message:        { type: "string", description: "Clear description of the finding" },
            recommendation: { type: "string", description: "Concrete action to resolve the finding" }
          }
        }.freeze

        SCHEMA = {
          name: "review_domain",
          description: "Return structured DDD review findings for a domain model",
          input_schema: {
            type: "object",
            required: %w[overall_score summary findings],
            properties: {
              overall_score: { type: "integer", description: "Overall domain quality score from 1 (poor) to 10 (excellent)" },
              summary:       { type: "string",  description: "Brief overall assessment of the domain model" },
              findings:      { type: "array",   items: FINDING_ITEM }
            }
          }
        }.freeze
      end
    end
  end
end
