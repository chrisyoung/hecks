module Hecks
  module ValidationRules
    module Structure
    # Commands must have at least one attribute
    class CommandsHaveAttributes < BaseRule
      def errors
        result = []
        @domain.aggregates.each do |agg|
          agg.commands.each do |cmd|
            if cmd.attributes.empty?
              result << "Command #{cmd.name} in #{agg.name} has no attributes."
            end
          end
        end
        result
      end
    end
    end
  end
end
