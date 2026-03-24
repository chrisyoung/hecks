# Hecks::Services::Querying::QueryBuilder::InMemoryExecutor
#
# Fallback query engine for adapters without native query support,
# or when conditions include OR nodes. Filters using the condition
# tree, then sorts, offsets, and limits results in Ruby. Included
# into QueryBuilder and invoked when the repo lacks a #query method.
#
#   # Used internally by QueryBuilder#execute:
#   #   in_memory_execute  # => filtered, sorted, paginated Array
#
module Hecks
  module Services
    module Querying
      class QueryBuilder
        module InMemoryExecutor
          private

          def in_memory_execute
            results = @repo.respond_to?(:all) ? @repo.all : []
            results = apply_conditions(results)
            results = apply_order(results)
            results = apply_offset(results)
            results = apply_limit(results)
            results
          end

          def apply_conditions(results)
            return results if @condition_tree.conditions.empty? && @condition_tree.children.empty?

            results.select { |obj| @condition_tree.match?(obj) }
          end

          def apply_order(results)
            return results unless @order_key

            sorted = results.sort_by do |obj|
              val = obj.respond_to?(@order_key) ? obj.send(@order_key) : nil
              val.nil? ? "" : val
            end

            @order_direction == :desc ? sorted.reverse : sorted
          end

          def apply_offset(results)
            return results unless @offset_value
            results.drop([@offset_value, 0].max)
          end

          def apply_limit(results)
            return results unless @limit_value
            results.take([@limit_value, 0].max)
          end
        end
      end
    end
  end
end
