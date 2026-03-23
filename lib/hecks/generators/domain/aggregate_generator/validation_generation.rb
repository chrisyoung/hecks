# Hecks::Generators::Domain::AggregateGenerator::ValidationGeneration
#
# Mixin that generates the validate! method for aggregate classes.
#
# Produces presence and type checks based on the aggregate's validation rules.
#
#   class AggregateGenerator
#     include ValidationGeneration
#   end
#
module Hecks
  module Generators
    module Domain
      class AggregateGenerator
        module ValidationGeneration
          private

          def validation_lines
            if @aggregate.validations.empty?
              return ["    def validate!; end"]
            end

            lines = ["    def validate!"]
            @aggregate.validations.each do |v|
              field = v.field
              rules = v.rules

              if rules[:presence]
                lines << "      raise ValidationError, \"#{field} can't be blank\" if #{field}.nil? || (#{field}.respond_to?(:empty?) && #{field}.empty?)"
              end

              if rules[:type]
                lines << "      raise ValidationError, \"#{field} must be a #{rules[:type]}\" unless #{field}.is_a?(#{rules[:type]})"
              end
            end
            lines << "    end"
            lines
          end
        end
      end
    end
  end
end
