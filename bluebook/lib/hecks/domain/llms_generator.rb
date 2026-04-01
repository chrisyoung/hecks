module Hecks
  # Hecks::LlmsGenerator
  #
  # Walks the domain IR and produces an AI-readable plain text summary suitable
  # for llms.txt files. Includes domain name, aggregates with attributes and
  # types, commands with parameters, queries, specifications, policies with
  # event-command mappings, validation rules, invariants, and reactive flow
  # chains.
  #
  #   Hecks::LlmsGenerator.new(domain).generate  # => String (plain text)
  #   Hecks::LlmsGenerator.new(domain).print     # prints to stdout
  #
  class LlmsGenerator
    # @param domain [Hecks::DomainModel::Structure::Domain] the domain IR
    def initialize(domain)
      @domain = domain
    end

    # Generate the full llms.txt content as a single string.
    #
    # @return [String] AI-readable plain text summary of the domain
    def generate
      lines = []
      lines << "# #{@domain.name} Domain"
      lines << ""
      lines << "This document describes the #{@domain.name} domain model for use by AI assistants."
      lines << ""

      @domain.aggregates.each do |agg|
        lines.concat(describe_aggregate(agg))
        lines << ""
      end

      lines.concat(describe_domain_policies)
      lines.concat(describe_reactive_flows)

      lines.join("\n")
    end

    # Print the llms.txt content to stdout.
    #
    # @return [nil]
    def print
      puts generate
      nil
    end

    private

    # Describe a single aggregate: attributes, commands, queries,
    # specifications, validations, invariants, and policies.
    #
    # @param agg [Hecks::DomainModel::Structure::Aggregate]
    # @return [Array<String>]
    def describe_aggregate(agg)
      lines = []
      lines << "## Aggregate: #{agg.name}"
      lines << ""

      lines.concat(describe_attributes(agg))
      lines.concat(describe_value_objects(agg))
      lines.concat(describe_commands(agg))
      lines.concat(describe_queries(agg))
      lines.concat(describe_specifications(agg))
      lines.concat(describe_validations(agg))
      lines.concat(describe_invariants(agg))
      lines.concat(describe_aggregate_policies(agg))
      lines
    end

    # @return [Array<String>]
    def describe_attributes(agg)
      return [] if agg.attributes.empty?
      lines = ["### Attributes", ""]
      agg.attributes.each do |attr|
        lines << "- #{attr.name}: #{Hecks::Utils.type_label(attr)}"
      end
      lines << ""
      lines
    end

    # @return [Array<String>]
    def describe_value_objects(agg)
      return [] if agg.value_objects.empty?
      lines = ["### Value Objects", ""]
      agg.value_objects.each do |vo|
        attrs = vo.attributes.map { |a| "#{a.name}: #{a.type}" }.join(", ")
        lines << "- #{vo.name} (#{attrs})"
      end
      lines << ""
      lines
    end

    # @return [Array<String>]
    def describe_commands(agg)
      return [] if agg.commands.empty?
      lines = ["### Commands", ""]
      agg.commands.each_with_index do |cmd, i|
        event = agg.events[i]
        params = cmd.attributes.map { |a| "#{a.name}: #{Hecks::Utils.type_label(a)}" }.join(", ")
        event_info = event ? " -> emits #{event.name}" : ""
        lines << "- #{cmd.name}(#{params})#{event_info}"
        cmd.preconditions.each { |c| lines << "  Precondition: #{c.message}" }
        cmd.postconditions.each { |c| lines << "  Postcondition: #{c.message}" }
      end
      lines << ""
      lines
    end

    # @return [Array<String>]
    def describe_queries(agg)
      return [] if agg.queries.empty?
      lines = ["### Queries", ""]
      agg.queries.each { |q| lines << "- #{q.name}" }
      lines << ""
      lines
    end

    # @return [Array<String>]
    def describe_specifications(agg)
      return [] if agg.specifications.empty?
      lines = ["### Specifications", ""]
      agg.specifications.each do |s|
        desc = s.description ? " -- #{s.description}" : ""
        lines << "- #{s.name}#{desc}"
      end
      lines << ""
      lines
    end

    # @return [Array<String>]
    def describe_validations(agg)
      return [] if agg.validations.empty?
      lines = ["### Validation Rules", ""]
      agg.validations.each do |v|
        rules = []
        rules << "must be present" if v.rules[:presence]
        rules << "must be #{v.rules[:type]}" if v.rules[:type]
        rules << "must be unique" if v.rules[:uniqueness]
        v.rules.each do |rule, value|
          next if %i[presence type uniqueness].include?(rule)
          rules << "#{rule}: #{value}"
        end
        lines << "- #{v.field}: #{rules.join(', ')}"
      end
      lines << ""
      lines
    end

    # @return [Array<String>]
    def describe_invariants(agg)
      return [] if agg.invariants.empty?
      lines = ["### Invariants", ""]
      agg.invariants.each { |inv| lines << "- #{inv.message}" }
      lines << ""
      lines
    end

    # @return [Array<String>]
    def describe_aggregate_policies(agg)
      return [] if agg.policies.empty?
      lines = ["### Policies", ""]
      agg.policies.each { |pol| lines << policy_line(pol) }
      lines << ""
      lines
    end

    # Describe domain-level (cross-aggregate) policies.
    #
    # @return [Array<String>]
    def describe_domain_policies
      return [] if @domain.policies.empty?
      lines = ["## Domain Policies", ""]
      @domain.policies.each { |pol| lines << policy_line(pol) }
      lines << ""
      lines
    end

    # Format a single policy as a readable line.
    #
    # @param pol [Hecks::DomainModel::Behavior::Policy]
    # @return [String]
    def policy_line(pol)
      async_note = pol.async ? " [async]" : ""
      if pol.reactive?
        "- #{pol.name}: when #{pol.event_name} occurs, trigger #{pol.trigger_command}#{async_note}"
      else
        "- #{pol.name}: guard policy"
      end
    end

    # Build the reactive flow chains section, tracing command -> event ->
    # policy -> command chains across all aggregates and domain policies.
    #
    # @return [Array<String>]
    def describe_reactive_flows
      chains = build_chains
      return [] if chains.empty?

      lines = ["## Reactive Flows", ""]
      lines << "These are the command -> event -> policy -> command chains:"
      lines << ""
      chains.each { |chain| lines << "- #{chain}" }
      lines << ""
      lines
    end

    # Build chain descriptions by matching command events to policies.
    #
    # @return [Array<String>]
    def build_chains
      all_policies = @domain.policies.dup
      @domain.aggregates.each { |agg| all_policies.concat(agg.policies) }

      chains = []
      @domain.aggregates.each do |agg|
        agg.commands.each_with_index do |cmd, i|
          event = agg.events[i]
          next unless event
          matching = all_policies.select { |p| p.reactive? && p.event_name == event.name }
          matching.each do |pol|
            chains << "#{cmd.name} -> #{event.name} -> #{pol.name} -> #{pol.trigger_command}"
          end
        end
      end
      chains
    end
  end
end
