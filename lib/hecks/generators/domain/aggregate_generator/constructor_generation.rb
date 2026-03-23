# Hecks::Generators::Domain::AggregateGenerator::ConstructorGeneration
#
# Mixin that generates initialize method and constructor parameters for aggregates.
#
# Handles both keyword-style (when attribute names clash with Ruby keywords)
# and standard keyword argument constructors.
#
#   class AggregateGenerator
#     include ConstructorGeneration
#   end
#
module Hecks
  module Generators
    module Domain
      class AggregateGenerator
        module ConstructorGeneration
          private

          def constructor_lines
            lines = []
            if @has_keyword_attrs
              lines << "    def initialize(**kwargs)"
              lines << "      @id = kwargs[:id] || generate_id"
              @user_attrs.each do |attr|
                if attr.list?
                  lines << "      @#{attr.name} = (kwargs[:#{attr.name}] || []).freeze"
                elsif attr.default
                  lines << "      @#{attr.name} = kwargs.fetch(:#{attr.name}, #{attr.default.inspect})"
                else
                  lines << "      @#{attr.name} = kwargs[:#{attr.name}]"
                end
              end
              lines << "      @created_at = kwargs[:created_at] || Time.now"
              lines << "      @updated_at = kwargs[:updated_at] || Time.now"
            else
              lines << "    def initialize(#{constructor_params})"
              lines << "      @id = id || generate_id"
              @user_attrs.each do |attr|
                if attr.list?
                  lines << "      @#{attr.name} = #{attr.name}.freeze"
                else
                  lines << "      @#{attr.name} = #{attr.name}"
                end
              end
              lines << "      @created_at = created_at || Time.now"
              lines << "      @updated_at = updated_at || Time.now"
            end
            lines << "      validate!"
            lines << "      check_invariants!"
            lines << "    end"
            lines
          end

          def constructor_params
            params = @user_attrs.map do |attr|
              if attr.list?
                "#{attr.name}: []"
              elsif attr.default
                "#{attr.name}: #{attr.default.inspect}"
              else
                "#{attr.name}: nil"
              end
            end
            params << "id: nil"
            params << "created_at: nil"
            params << "updated_at: nil"
            params.join(", ")
          end
        end
      end
    end
  end
end
