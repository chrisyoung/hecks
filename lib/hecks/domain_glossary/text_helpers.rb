# Hecks::DomainGlossary::TextHelpers
#
# English text utilities for glossary generation — articles, pluralization,
# humanization, and list formatting.
#
module Hecks
  class DomainGlossary
    module TextHelpers
      private

      def article(word)
        %w[a e i o u].include?(word[0]&.downcase) ? "an" : "a"
      end

      def an(word, capitalize: true)
        a = article(word)
        a = a.capitalize if capitalize
        "#{a} #{word}"
      end

      def pluralize(word)
        return word if word.end_with?("s")
        word.end_with?("y") ? word[0..-2] + "ies" : word + "s"
      end

      def humanize(name)
        name.gsub(/([A-Z])/, ' \1').strip.downcase
      end

      def english_list(items)
        case items.size
        when 0 then ""
        when 1 then items[0]
        when 2 then "#{items[0]} and #{items[1]}"
        else "#{items[0..-2].join(', ')}, and #{items[-1]}"
        end
      end
    end
  end
end
