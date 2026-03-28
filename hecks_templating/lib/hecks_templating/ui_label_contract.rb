# = Hecks::UILabelContract
#
# Single source of truth for converting field names to display labels.
# Consumed by Ruby and Go UI generators, server generators, and the
# smoke test. Prevents label formatting drift across targets.
#
#   Hecks::UILabelContract.label(:effective_date)  # => "Effective Date"
#   Hecks::UILabelContract.label("model_id")       # => "Model Id"
#
module Hecks
  module UILabelContract
    def self.label(field_name)
      field_name.to_s.split("_").map(&:capitalize).join(" ")
    end
  end
end
