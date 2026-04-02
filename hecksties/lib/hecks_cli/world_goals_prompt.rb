# HecksCLI::WorldGoalsPrompt
#
# Handles the interactive onboarding prompt that asks users to declare
# world concerns (ethical commitments) for their new domain.
#
# Usage:
#   result = WorldGoalsPrompt.run(shell: shell)
#   # result is one of:
#   #   { mode: :goals, goals: [:privacy, :consent] }
#   #   { mode: :skip }
#   #   { mode: :not_applicable }
#
module HecksCLI
  module WorldGoalsPrompt
    VALID_GOALS = %i[privacy transparency equity sustainability consent security].freeze

    def self.run(shell:)
      shell.say ""
      shell.say "Welcome to Hecks."
      shell.say ""
      shell.say "Hecks is built on the belief that software affects living beings —"
      shell.say "humans, animals, ecosystems. The domain you're about to model will"
      shell.say "touch some of them."
      shell.say ""
      shell.say "Would you like to declare world goals for this domain?"
      shell.say ""
      shell.say "  1. Yes — walk me through them"
      shell.say "  2. Skip for now — I'll add them later"
      shell.say "  3. This doesn't apply to my project"
      shell.say ""

      choice = $stdin.gets&.chomp&.strip

      case choice
      when "1"
        shell.say ""
        shell.say "Available goals: #{VALID_GOALS.map(&:to_s).join(', ')}"
        shell.say ""
        shell.say "Select goals (comma-separated, or press Enter to skip):"
        input = $stdin.gets&.chomp&.strip || ""
        goals = parse_goals(input)
        shell.say ""
        if goals.any?
          shell.say "Domain created. World goals declared.", :green
        else
          shell.say "Domain created.", :green
        end
        { mode: :goals, goals: goals }
      when "3"
        { mode: :not_applicable }
      else
        { mode: :skip }
      end
    end

    def self.parse_goals(input)
      return [] if input.empty?

      input.split(/[\s,]+/).map(&:to_sym) & VALID_GOALS
    end
  end
end
