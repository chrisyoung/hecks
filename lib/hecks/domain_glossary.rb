# Hecks::DomainGlossary
#
# Walks the domain IR and produces plain-English statements that describe
# the domain model. Use it to validate your reasoning about the domain.
#
#   Hecks::DomainGlossary.new(domain).generate
#   # => ["A Pizza has a name (String).",
#   #     "A Pizza has many Toppings.",
#   #     "A Pizza can be created with a name and style.",
#   #     ...]
#
module Hecks
  class DomainGlossary
    def initialize(domain)
      @domain = domain
    end

    def generate
      lines = []
      lines << "# #{@domain.name} Domain Glossary"
      lines << ""

      @domain.aggregates.each do |agg|
        lines.concat(describe_aggregate(agg))
        lines << ""
      end

      lines.concat(describe_relationships)
      lines
    end

    def print
      puts generate.join("\n")
      nil
    end

    def generate_for(agg)
      describe_aggregate(agg)
    end

    def print_for(agg)
      puts generate_for(agg).join("\n")
      nil
    end

    private

    def describe_aggregate(agg)
      lines = []
      lines << "## #{agg.name}"
      lines << ""

      # Attributes
      agg.attributes.each do |attr|
        lines << attribute_statement(agg.name, attr)
      end

      # Value objects
      agg.value_objects.each do |vo|
        lines << "#{an(vo.name)} is part of #{an(agg.name, capitalize: false)}."
        vo.attributes.each do |attr|
          lines << "  #{an(vo.name)} has #{article(attr.name.to_s)} #{attr.name} (#{attr.type})."
        end
        vo.invariants.each do |inv|
          lines << "  #{inv.message}. (invariant)"
        end
      end

      # Commands
      agg.commands.each_with_index do |cmd, i|
        event = agg.events[i]
        lines << command_statement(agg.name, cmd, event)
      end

      # Queries
      agg.queries.each do |q|
        lines << "You can look up #{pluralize(agg.name)} by #{humanize(q.name)}. (query)"
      end

      # Validations
      agg.validations.each do |v|
        lines << "#{an(agg.name)} must have #{article(v.field.to_s)} #{v.field}. (validation)" if v.rules[:presence]
        v.rules.each do |rule, value|
          next if rule == :presence
          lines << "#{an(agg.name)}'s #{v.field} must be #{rule}: #{value}. (validation)"
        end
      end

      # Invariants
      agg.invariants.each do |inv|
        lines << "#{inv.message}. (invariant)"
      end

      # Policies
      agg.policies.each do |pol|
        lines << policy_statement(agg.name, pol)
      end

      lines
    end

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
      # "PlacedOrder" → verb="Placed", noun="Order" → "When an Order is placed"
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
