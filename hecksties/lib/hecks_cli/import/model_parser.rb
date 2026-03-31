module Hecks
  module Import
    # Hecks::Import::ModelParser
    #
    # Reads Rails model files as text and extracts conventions via pattern
    # matching. No Rails boot required — just file reads and regexes.
    # Handles belongs_to, has_many, validates, enum, and AASM state machines.
    #
    #   ModelParser.new("app/models").parse
    #   # => { "Pizza" => { associations: [...], validations: [...], enums: {...}, state_machine: {...} } }
    #
    class ModelParser
      def initialize(models_dir)
        @models_dir = models_dir
      end

      def parse
        results = {}
        Dir[File.join(@models_dir, "*.rb")].each do |path|
          content = File.read(path)
          class_name = extract_class_name(content)
          next unless class_name
          results[class_name] = {
            associations: extract_associations(content),
            validations:  extract_validations(content),
            enums:        extract_enums(content),
            state_machine: extract_state_machine(content)
          }
        end
        results
      end

      private

      def extract_class_name(content)
        match = content.match(/class\s+(\w+)\s*</)
        match && match[1]
      end

      def extract_associations(content)
        assocs = []
        content.scan(/belongs_to\s+:(\w+)/) { |m| assocs << { type: :belongs_to, name: m[0] } }
        content.scan(/has_many\s+:(\w+)(?:,\s*through:\s*:(\w+))?/) do |name, through|
          assocs << { type: :has_many, name: name, through: through }
        end
        content.scan(/has_one\s+:(\w+)/) { |m| assocs << { type: :has_one, name: m[0] } }
        assocs
      end

      def extract_validations(content)
        validations = []
        content.scan(/validates?\s+:(\w+),\s*(.+?)$/) do |field, rules_str|
          rules = parse_validation_rules(rules_str.strip)
          validations << { field: field, rules: rules } if rules.any?
        end
        validations
      end

      def extract_enums(content)
        enums = {}
        # Rails 6: enum status: { draft: 0, published: 1 }
        content.scan(/enum\s+(\w+):\s*\{([^}]+)\}/) do |field, values_str|
          enums[field] = values_str.scan(/(\w+):/).flatten
        end
        # Rails 7: enum :status, { draft: 0, published: 1 }
        content.scan(/enum\s+:(\w+),\s*\{([^}]+)\}/) do |field, values_str|
          enums[field] = values_str.scan(/(\w+):/).flatten
        end
        # Rails 7 array: enum :status, [:draft, :published]
        content.scan(/enum\s+:(\w+),\s*\[([^\]]+)\]/) do |field, values_str|
          enums[field] = values_str.scan(/:(\w+)/).flatten
        end
        enums
      end

      def extract_state_machine(content)
        return nil unless content.match?(/include\s+AASM|aasm\b|state_machine\b/)
        sm = { field: "status", initial: nil, transitions: [] }
        # AASM column
        if (col_match = content.match(/aasm(?:\s*\(?\s*column:\s*:(\w+))?/))
          sm[:field] = col_match[1] || "status"
        end
        # Initial state
        if (init_match = content.match(/state\s+:(\w+),\s*initial:\s*true/))
          sm[:initial] = init_match[1]
        end
        # Transitions: event :publish do transitions from: :draft, to: :published
        content.scan(/event\s+:(\w+)\s+do\s+.*?transitions\s+from:\s*:(\w+),\s*to:\s*:(\w+)/m) do |event, from, to|
          sm[:transitions] << { event: event, from: from, to: to }
        end
        sm[:transitions].any? ? sm : nil
      end

      def parse_validation_rules(rules_str)
        rules = {}
        rules[:presence] = true if rules_str.include?("presence: true") || rules_str.include?("presence:")
        rules[:uniqueness] = true if rules_str.include?("uniqueness: true") || rules_str.include?("uniqueness:")
        rules
      end
    end
  end
end
