# = Hecks::Conventions::UILabelContract
#
# Single source of truth for converting names to display labels.
# Handles both snake_case (field names) and PascalCase (command
# names, aggregate names). Uses ActiveSupport for pluralization.
#
#   Hecks::Conventions::UILabelContract.label(:effective_date)    # => "Effective Date"
#   Hecks::Conventions::UILabelContract.label("ReportIncident")   # => "Report Incident"
#   Hecks::Conventions::UILabelContract.plural_label("GovernancePolicy")  # => "Governance Policies"
#
require "active_support/core_ext/string/inflections"

module Hecks::Conventions
  module UILabelContract
    # Convert any name (snake_case or PascalCase) to a display label.
    # Strips trailing "_id" from reference attribute names so that
    # "pizza_id" renders as "Pizza" rather than "Pizza Id".
    def self.label(name)
      s = name.to_s
      s = s.gsub(/([A-Z]+)([A-Z][a-z])/, '\1 \2')
           .gsub(/([a-z\d])([A-Z])/, '\1 \2')
      result = s.split(/[_ ]+/).map(&:capitalize).join(" ")
      result = result.sub(/ Id$/, "") if name.to_s.end_with?("_id")
      result
    end

    # Humanized plural label for an aggregate or entity name.
    # "GovernancePolicy" → "Governance Policies"
    def self.plural_label(name)
      words = label(name).split(" ")
      words[-1] = words[-1].pluralize
      words.join(" ")
    end
  end
end
