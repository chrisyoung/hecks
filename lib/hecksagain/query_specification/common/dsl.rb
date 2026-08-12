require_relative "authorization_spec"
require_relative "comparators"
require_relative "consistency_spec"
require_relative "cursor_spec"
require_relative "freshness_spec"
require_relative "index_hint"
require_relative "inspection_spec"
require_relative "limit_spec"
require_relative "null_semantics"
require_relative "offset_spec"
require_relative "order_by"
require_relative "where_clause"

module Hecksagain
  module QuerySpecification
    module Common
      module DSL
        def where(clauses)
          @wheres ||= []
          clauses.each do |field, value|
            op, operand = split_comparator(value)
            @wheres << WhereClause.new(field: field, op: op, value: operand)
          end
        end

        # ONE FIELD, AND A DIRECTION THAT IS A DIRECTION.
        #
        # `order_by :order, :sequence` reads as "by order, then by sequence"
        # and did something else entirely: `:sequence` landed in `direction`,
        # and every adapter renders a direction as `desc ? "DESC" : "ASC"` —
        # so the second field was not merely dropped, it was silently read as
        # a request for ascending order and thrown away. The query answered
        # rows in the wrong sequence and refused nothing.
        #
        # Found on the QA ledger's own `Queue`, where the ordering IS the
        # feature: a bug ranked 1 came back behind two ranked 1000, and the
        # only clue was that the answer looked wrong.
        #
        # REFUSED, NOT SUPPORTED, and the difference is deliberate. Ordering
        # by several fields is a real feature — it needs an IR that carries a
        # list, adapters that render `ORDER BY a, b`, and the self-hosted
        # grammar to say so. This is the bug fix: the ambiguity becomes a
        # sentence instead of a wrong answer, and a caller who wanted two
        # fields is told so rather than quietly given one.
        ORDER_DIRECTIONS = %i[asc desc].freeze

        def order_by(field, direction = :asc)
          # NOT AGAINST HISTORY. A held era text is re-parsed on every boot to
          # compute that era's shape, and it may legally contain a call this
          # rule was invented to stop — era 4 of the QA ledger holds the exact
          # mistake that prompted the rule. Refusing there makes a ledger that
          # booted yesterday unopenable, over a line nobody is allowed to edit.
          unless Runtime::EraGuard.replaying? ||
                 ORDER_DIRECTIONS.include?(direction.to_s.downcase.to_sym)
            raise Bluebook::DSL::Malformed,
                  "order_by #{field.inspect}, #{direction.inspect} — the second argument is a " \
                  "DIRECTION (:asc or :desc), not a second field. Ordering by more than one " \
                  "field is not declarable yet; say which single field decides the order."
          end

          @order_by = OrderBy.new(field: field, direction: direction)
        end

        def limit(value) = @limit = LimitSpec.new(value: value)
        def offset(value) = @offset = OffsetSpec.new(value: value)
        def cursor(value) = @cursor = CursorSpec.new(value: value)
        def consistency(mode, timeout: nil) = @consistency = ConsistencySpec.new(mode: mode, timeout: timeout)
        def freshness(mode, max_age: nil) = @freshness = FreshnessSpec.new(mode: mode, max_age: max_age)
        def authorize(policy, tenant: nil) = @authorization = AuthorizationSpec.new(policy: policy, tenant: tenant)
        def nulls(mode) = @null_semantics = NullSemantics.new(mode: mode)
        def inspect_query(mode = :sql) = @inspection = InspectionSpec.new(mode: mode)

        def use_index(name)
          @index_hints ||= []
          @index_hints << IndexHint.new(name: name)
        end

        private

        def split_comparator(value)
          return [:eq, value] unless value.is_a?(Hash)

          op, operand = value.first
          unless value.size == 1 && COMPARATORS.include?(op.to_sym)
            raise ArgumentError,
                  "unknown comparator #{value.inspect} — expected one of #{COMPARATORS.join(', ')}"
          end
          [op.to_sym, operand]
        end
      end
    end
  end
end
