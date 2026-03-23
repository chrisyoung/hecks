# Hecks::ValidationRules::Naming::CommandNaming
#
# Rejects command names that do not start with a verb. Uses WordNet
# for detection. Custom verbs can be added in a verbs.txt file at
# the root of the domain folder (one word per line).
#
require "rwordnet"

module Hecks
  module ValidationRules
    module Naming
    class CommandNaming < BaseRule
      def errors
        custom = load_custom_verbs
        result = []
        @domain.aggregates.each do |agg|
          agg.commands.each do |cmd|
            first_word = cmd.name.split(/(?=[A-Z])/).first
            unless verb?(first_word, custom)
              result << "Command #{cmd.name} in #{agg.name} doesn't start with a verb. Commands should express intent (e.g. Create#{agg.name}). Add custom verbs to verbs.txt."
            end
          end
        end
        result
      end

      private

      def verb?(word, custom)
        return true if custom.include?(word)
        WordNet::Lemma.find_all(word.downcase).any? { |l| l.pos == "v" }
      end

      def load_custom_verbs
        return [] unless @domain.respond_to?(:source_path) && @domain.source_path
        verbs_file = File.join(File.dirname(@domain.source_path), "verbs.txt")
        return [] unless File.exist?(verbs_file)
        File.readlines(verbs_file).map(&:strip).reject(&:empty?)
      end
    end
    end
  end
end
