# Hecks::ValidationRules::Naming::CommandNaming
#
# Rejects command names that do not start with a verb. Uses WordNet
# to check if the first word is a known English verb. Domains can
# add custom verbs via `verbs "Dispatch"` for domain-specific terms.
#
require "rwordnet"

module Hecks
  module ValidationRules
    module Naming
    class CommandNaming < BaseRule
      def errors
        custom_verbs = @domain.respond_to?(:verbs) ? @domain.verbs : []
        result = []
        @domain.aggregates.each do |agg|
          agg.commands.each do |cmd|
            first_word = cmd.name.split(/(?=[A-Z])/).first
            unless verb?(first_word, custom_verbs)
              result << "Command #{cmd.name} in #{agg.name} doesn't start with a verb. Commands should express intent (e.g. Create#{agg.name}, Update#{agg.name}). Add custom verbs with: verbs \"#{first_word}\""
            end
          end
        end
        result
      end

      private

      def verb?(word, custom_verbs)
        return true if custom_verbs.include?(word)
        WordNet::Lemma.find_all(word.downcase).any? { |l| l.pos == "v" }
      end
    end
    end
  end
end
