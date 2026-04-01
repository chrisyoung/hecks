module Hecks
  module Import
    # Hecks::Import::RubyAssembler
    #
    # Builds a Hecks DSL domain definition from RubyParser output. Groups
    # classes by top-level module into aggregates. Classes without a module
    # become their own aggregate. Nested classes become value objects.
    #
    #   parsed = RubyParser.new("/path/to/lib").parse
    #   RubyAssembler.new(parsed, domain_name: "Billing").assemble
    #   # => 'Hecks.domain "Billing" do ...'
    #
    class RubyAssembler
      def initialize(parsed_classes, domain_name: "MyDomain")
        @parsed_classes = parsed_classes
        @domain_name = domain_name
      end

      def assemble
        lines = ["Hecks.domain \"#{@domain_name}\" do"]
        aggregates = group_into_aggregates
        aggregates.each_with_index do |(agg_name, members), i|
          lines << "" if i > 0
          lines.concat(assemble_aggregate(agg_name, members))
        end
        lines << "end"
        lines.join("\n") + "\n"
      end

      private

      def group_into_aggregates
        groups = {}
        @parsed_classes.each do |cls|
          group = cls[:module] || cls[:name]
          (groups[group] ||= []) << cls
        end
        groups
      end

      def assemble_aggregate(agg_name, members)
        root = members.first
        lines = ["  aggregate \"#{agg_name}\" do"]

        # Root class attributes
        (root[:attributes] || []).each do |attr|
          lines << "    attribute :#{attr[:name]}, #{attr[:type]}"
        end

        # Nested classes as value objects
        (root[:nested_classes] || []).each do |nested|
          lines.concat(assemble_value_object(nested))
        end

        # Additional classes in same module as value objects
        members[1..].each do |cls|
          lines.concat(assemble_value_object(cls))
        end

        # Create command with all attributes
        writable = root[:attributes] || []
        if writable.any?
          lines << ""
          lines << "    command \"Create#{agg_name}\" do"
          writable.each do |attr|
            lines << "      attribute :#{attr[:name]}, #{attr[:type]}"
          end
          lines << "    end"
        end

        lines << "  end"
        lines
      end

      def assemble_value_object(cls)
        lines = [""]
        lines << "    value_object \"#{cls[:name]}\" do"
        (cls[:attributes] || []).each do |attr|
          lines << "      attribute :#{attr[:name]}, #{attr[:type]}"
        end
        lines << "    end"
        lines
      end
    end
  end
end
