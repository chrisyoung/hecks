module Hecks
  module ValidationRules
    module Structure
    # Every aggregate should have at least one command
    class AggregatesHaveCommands < BaseRule
      def errors
        result = []
        @domain.aggregates.each do |agg|
          if agg.commands.empty?
            result << "#{agg.name} has no commands. An aggregate without commands is a data bag, not a behavior boundary."
          end
        end
        result
      end
    end
    end
  end
end
