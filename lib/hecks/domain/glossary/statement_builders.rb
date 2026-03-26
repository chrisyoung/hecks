# Hecks::DomainGlossary::StatementBuilders
#
# Builds plain-English statements from domain IR objects — attributes,
# commands, policies, and relationships.
#
module Hecks
  class DomainGlossary
    module StatementBuilders
      private

      def attribute_statement(agg_name, attr)
        a = an(agg_name)
        if attr.list?
          "#{a} has many #{pluralize(attr.type.to_s)}."
        elsif attr.reference?
          "#{a} belongs to #{an(attr.type.to_s, capitalize: false)}."
        else
          "#{a} has #{article(attr.name.to_s)} #{attr.name} (#{attr.type})."
        end
      end

      def command_statement(agg_name, cmd, event)
        verb = cmd.name.split(/(?=[A-Z])/).first.downcase
        attrs = cmd.attributes.map { |a| a.name.to_s.tr("_", " ") }
        params = attrs.empty? ? "" : " with #{english_list(attrs)}"
        if event
          event_parts = event.name.split(/(?=[A-Z])/)
          past_verb = event_parts.first.downcase
          event_noun = event_parts[1..].join
          subject = event_noun.empty? ? an(agg_name, capitalize: false) : an(event_noun, capitalize: false)
          result = " When this happens, #{subject} is #{past_verb}."
        else
          result = ""
        end
        "You can #{verb} #{an(agg_name, capitalize: false)}#{params}.#{result} (command)"
      end

      def policy_statement(agg_name, pol)
        trigger_verb = pol.trigger_command.split(/(?=[A-Z])/).first.downcase
        trigger_target = pol.trigger_command.split(/(?=[A-Z])/)[1..].join
        async_note = pol.async ? " (asynchronously)" : ""
        event_parts = pol.event_name.split(/(?=[A-Z])/)
        verb = event_parts.first.downcase
        noun = event_parts[1..].join
        subject = noun.empty? ? an(agg_name, capitalize: false) : an(noun, capitalize: false)
        "When #{subject} is #{verb}, the system will #{trigger_verb} #{trigger_target}#{async_note}. (policy)"
      end

      def describe_relationships
        lines = []
        refs = []
        @domain.aggregates.each do |agg|
          agg.attributes.select(&:reference?).each do |attr|
            refs << [agg.name, attr.type.to_s]
          end
        end

        return lines if refs.empty?

        lines << "## Relationships"
        lines << ""
        refs.each do |from, to|
          lines << "#{an(from)} references #{an(to, capitalize: false)}."
        end
        lines
      end
    end
  end
end
