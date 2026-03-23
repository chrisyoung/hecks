# Hecks::DomainGlossary
#
# Walks the domain IR and produces plain-English statements that describe
# the domain model. Use it to validate your reasoning about the domain.
#
#   Hecks::DomainGlossary.new(domain).generate
#   Hecks::DomainGlossary.new(domain).print
#   domain.glossary
#
require_relative "domain_glossary/text_helpers"
require_relative "domain_glossary/statement_builders"

module Hecks
  class DomainGlossary
    include TextHelpers
    include StatementBuilders

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

      agg.attributes.each do |attr|
        lines << attribute_statement(agg.name, attr)
      end

      agg.value_objects.each do |vo|
        lines << "#{an(vo.name)} is part of #{an(agg.name, capitalize: false)}."
        vo.attributes.each do |attr|
          lines << "  #{an(vo.name)} has #{article(attr.name.to_s)} #{attr.name} (#{attr.type})."
        end
        vo.invariants.each do |inv|
          lines << "  #{inv.message}. (invariant)"
        end
      end

      agg.commands.each_with_index do |cmd, i|
        lines << command_statement(agg.name, cmd, agg.events[i])
      end

      agg.queries.each do |q|
        lines << "You can look up #{pluralize(agg.name)} by #{humanize(q.name)}. (query)"
      end

      agg.validations.each do |v|
        lines << "#{an(agg.name)} must have #{article(v.field.to_s)} #{v.field}. (validation)" if v.rules[:presence]
        v.rules.each do |rule, value|
          next if rule == :presence
          lines << "#{an(agg.name)}'s #{v.field} must be #{rule}: #{value}. (validation)"
        end
      end

      agg.invariants.each do |inv|
        lines << "#{inv.message}. (invariant)"
      end

      agg.policies.each do |pol|
        lines << policy_statement(agg.name, pol)
      end

      lines
    end
  end
end
