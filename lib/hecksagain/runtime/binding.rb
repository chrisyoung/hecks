require_relative "value"

module Hecksagain
  module Runtime
    # ADR 0029's own step 3 — the key/value argument-resolution
    # primitive, previously spelled out twice under different names:
    # `PolicyInterpreter#trigger_args` (a 2-branch resolution — a Symbol
    # names a field on the event's own payload, anything else is a
    # literal the policy supplies itself) and `SagaInterpreter#
    # dispatch_args` (the same function, with two MORE symbol sources
    # ranked ahead of the payload: the correlation head, then the
    # saga's own accumulated memory). Read side by side, these were
    # never two designs — one function, with `ReactionContext`-shaped
    # sources ADDED to the lookup chain, not a different function.
    #
    # This is that one function. `sources` names which chain a caller
    # wants: `PolicyInterpreter` passes one source (the merged event
    # payload); `SagaInterpreter` passes three, in the same priority
    # order its own `dispatch_args` always checked them in
    # (correlation head, then payload, then memory). Neither
    # interpreter's own observable resolution changes by this
    # extraction — every existing `with_spec` in the corpus still
    # resolves through the identical priority chain it always did,
    # just expressed once instead of twice.
    module Binding
      module_function

      # `sources` signal "no answer here, try the next source" by
      # returning THIS, not `nil` — `nil` is a real, final answer a
      # source can legitimately hold (`SagaInterpreter#dispatch_args`'s
      # own `event.payload.key?(value)` check picks a payload field
      # even when its value IS `nil`, rather than falling through to
      # memory the way treating "nil" itself as "not found" would).
      # Only a source that ISN'T the last in the chain ever needs to
      # return this — the last source always terminates the chain,
      # exactly like the original `else instance[:memory][value] end`
      # branch both hand-written functions ended on.
      NOT_FOUND = Object.new.freeze

      # `with_spec` — an Array of `[key, value]` pairs (a policy's or a
      # dispatch's own declared bindings). `sources` — an Array of
      # `Symbol -> value` callables (answering `NOT_FOUND` to defer to
      # the next one), tried in order for a Symbol value — the same
      # priority chain both original functions walked by hand by
      # writing more `elsif` branches. A non-Symbol value is always a
      # literal, never looked up — the one branch every real
      # `with_spec` value actually takes when it isn't naming a source
      # field.
      #
      # Every resolved value passes through `Value.materialize` before
      # being handed back — a reaction crosses an aggregate boundary,
      # and the value it carries must become the RECEIVING side's own
      # runtime type, not ride along as the SOURCE aggregate's (both
      # original functions' own comment, verbatim: "a saga carries a
      # value object's state, not its source aggregate's runtime type").
      def resolve(with_spec, sources)
        with_spec.to_h do |key, value|
          resolved = value.is_a?(Symbol) ? resolve_symbol(value, sources) : value
          [key.to_sym, Value.materialize(resolved)]
        end
      end

      def resolve_symbol(name, sources)
        sources.each do |source|
          value = source.call(name)
          return value unless value.equal?(NOT_FOUND)
        end
        nil
      end
    end
  end
end
