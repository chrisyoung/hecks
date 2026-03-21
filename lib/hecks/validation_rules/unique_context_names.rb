module Hecks
  module ValidationRules
    # No duplicate context names
    class UniqueContextNames < BaseRule
      def errors
        names = @domain.contexts.map(&:name)
        duplicates = names.select { |n| names.count(n) > 1 }.uniq

        duplicates.map do |name|
          "Duplicate context name: #{name}"
        end
      end
    end
  end
end
