# Hecks::ValidationRules::Naming::CommandNaming
#
# Rejects command names that do not start with a verb. Uses WordNet
# for detection. Custom verbs can be added in a verbs.txt file at
# the root of the domain folder (one word per line). Part of the
# ValidationRules::Naming group -- run by Hecks.validate.
#
begin
  require "rwordnet"
rescue LoadError
  # rwordnet is optional — verb checking degrades to custom verbs only
end

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
              result << "Command #{cmd.name} in #{agg.name} doesn't start with a verb. Try '#{suggest_verb(first_word, agg.name)}' or register '#{first_word}' as a custom verb in verbs.txt."
            end
          end
        end
        result
      end

      private

      def suggest_verb(first_word, agg_name)
        suffix = first_word == agg_name ? "" : first_word
        "Create#{agg_name}#{suffix}"
      end

      def verb?(word, custom)
        return true if custom.any? { |v| v.downcase == word.downcase }
        return false unless defined?(WordNet)
        WordNet::Lemma.find_all(word.downcase).any? { |l| l.pos == "v" }
      end

      def load_custom_verbs
        verbs = @domain.respond_to?(:custom_verbs) ? Array(@domain.custom_verbs) : []
        if @domain.respond_to?(:source_path) && @domain.source_path
          verbs_file = File.join(File.dirname(@domain.source_path), "verbs.txt")
          if File.exist?(verbs_file)
            verbs += File.readlines(verbs_file).map(&:strip).reject(&:empty?)
          end
        end
        verbs
      end
    end
    end
  end
end
