# Hecks::Generators::Domain::AggregateGenerator::ConstructorGeneration
#
# Mixin that generates initialize method and constructor parameters for aggregates.
# Timestamps (created_at, updated_at) are handled by the persistence layer.
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
            params.join(", ")
          end
        end
      end
    end
  end
end
