# Hecks::AI::Prompts::DomainEdit
#
# System prompt and tool schema for incremental domain edits via natural
# language. The LLM interprets a user request and returns a list of DSL
# operations (add_attribute, add_command, etc.) to apply to the current
# workshop session.
#
#   Hecks::AI::Prompts::DomainEdit::SYSTEM_PROMPT  # => String
#   Hecks::AI::Prompts::DomainEdit::TOOL_SCHEMA    # => Hash
#
module Hecks
  module AI
    module Prompts
      module DomainEdit
        SYSTEM_PROMPT = <<~PROMPT
          You are an expert domain modeler working inside the Hecks workshop REPL.
          The user describes changes to their domain in plain English. You translate
          each request into a sequence of DSL operations.

          Available operations:
          - add_aggregate: create a new aggregate
          - add_attribute: add an attribute to an aggregate
          - add_command: add a command to an aggregate
          - add_command_attribute: add an attribute to a command
          - add_value_object: add a value object to an aggregate
          - add_reference: add a reference_to between aggregates
          - add_lifecycle: add lifecycle state tracking
          - add_transition: add a state transition command
          - remove_aggregate: remove an aggregate
          - remove_attribute: remove an attribute from an aggregate
          - remove_command: remove a command from an aggregate

          Rules:
          - Aggregate names are PascalCase (e.g. Pizza, OrderItem)
          - Command names are PascalCase VerbNoun (e.g. CreatePizza, PlaceOrder)
          - Attribute types: String, Integer, Float, Boolean, Date, DateTime
          - Collection types: list_of(TypeName)
          - Reference types: reference_to(TypeName)
          - Always include a Create command when adding a new aggregate
          - Return ONLY operations, no explanations
        PROMPT

        OPERATION_SCHEMA = {
          type: "object",
          required: %w[op],
          properties: {
            op:        { type: "string", enum: %w[
              add_aggregate add_attribute add_command add_command_attribute
              add_value_object add_reference add_lifecycle add_transition
              remove_aggregate remove_attribute remove_command
            ] },
            aggregate: { type: "string", description: "Target aggregate name" },
            name:      { type: "string", description: "Name of the item" },
            type:      { type: "string", description: "Attribute type" },
            command:   { type: "string", description: "Command name (for add_command_attribute/transition)" },
            field:     { type: "string", description: "Lifecycle field name" },
            default:   { type: "string", description: "Lifecycle default state" },
            target:    { type: "string", description: "Transition target state or reference target" },
            attributes: {
              type: "array",
              items: {
                type: "object",
                properties: {
                  name: { type: "string" },
                  type: { type: "string" }
                }
              },
              description: "Value object attributes"
            }
          }
        }.freeze

        TOOL_SCHEMA = {
          name: "edit_domain",
          description: "Apply incremental edits to the current domain model",
          input_schema: {
            type: "object",
            required: %w[operations],
            properties: {
              operations: {
                type: "array",
                items: OPERATION_SCHEMA,
                description: "Ordered list of DSL operations to apply"
              }
            }
          }
        }.freeze
      end
    end
  end
end
