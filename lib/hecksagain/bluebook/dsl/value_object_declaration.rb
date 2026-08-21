module Hecksagain
  module Bluebook
    module DSL
      # ADR 0029 step 1 (S10, ADR 0025's own "declared once, referenced
      # by name" family, one member wider than `given`) — extracted from
      # `AggregateBuilder` the moment adding it pushed that class past
      # `Metrics/ClassLength`, the same reason `AttributeCollector`/
      # `IdentityDeclaration`/`RuleReference` are their own mixins rather
      # than inline methods there already. Assumes the including class
      # provides `@value_objects`/`closed_sets` (`AttributeCollector`),
      # `@name`, `@chapter_value_objects` (threaded from `BluebookBuilder
      # #aggregate`, the identical way `@chapter_named_givens` is), and
      # `RuleReference`'s own primitives (`verify_resolves_via!`,
      # `resolve_owner_keyed`) — `AggregateBuilder` is the one, so-far-
      # only includer, and already includes all four.
      module ValueObjectDeclaration
        # `reaction.bluebook`'s own `Policy`/`ProcessManager` declared
        # byte-identical `Binding` value objects, because no aggregate
        # could reference a SIBLING aggregate's own already-declared
        # value object by name; the same real duplication `given`'s own
        # chapter-wide sharing (S10) already closed one construct over.
        #
        # NO BLOCK is a REFERENCE, not a fresh declaration — the exact
        # shape `AggregateBuilder#given_impl`/`CommandBuilder#given_impl`
        # already established: the SAME word, minus the block, resolved
        # against whatever the CHAPTER has declared so far. `declared_by:`
        # disambiguates the same name meaning two genuinely different
        # value objects chapter-wide — see `given`'s own `declared_by:`
        # comment for the full reasoning, shared verbatim here. NOT a
        # cure-all: a name reused independently across MANY unrelated
        # constructs (`Position`, declared by six different aggregates in
        # this very chapter for six genuinely different facts) should
        # stay separately declared — this mechanism is for the SAME fact
        # duplicated, not every name that happens to collide.
        def value_object(name, declared_by: nil, &block)
          return reference_named_chapter_value_object(name, declared_by: declared_by) unless block

          builder = ValueObjectBuilder.new(name, owner_value_objects: @value_objects + closed_sets)
          builder.instance_eval(&block)
          built             = builder.build
          built_closed_sets = builder.closed_sets
          @value_objects << built
          @value_objects.concat(built_closed_sets)

          # WRITE-THROUGH, first-declared-wins PER OWNER — the identical
          # shape `given_impl`'s own write-through takes
          # (`@chapter_named_givens[description][@name] ||= named`):
          # keyed by [name, this aggregate's own name], not name alone,
          # so two DIFFERENT aggregates independently declaring the
          # SAME-NAMED value object are two DISTINCT candidates a later
          # bare reference chooses between, never silently merged into
          # one slot. Caches BOTH `built` and its own `built_closed_sets`
          # together — a referencing aggregate needs whatever inline
          # `one_of` sets this value object's own attributes synthesised
          # too, not just the value object itself.
          @chapter_value_objects[name] ||= {}
          @chapter_value_objects[name][@name] ||= [built, built_closed_sets]
        end

        private

        # PRIMITIVE 2 (RuleReference#resolve_owner_keyed) — the identical
        # shape `AggregateBuilder#reference_named_chapter_given`'s own
        # comment describes. Pushes the SAME already-built value object
        # (and its own closed sets) into THIS aggregate's own
        # `@value_objects` — the wire format is unaffected by this
        # sharing (`Bluebook.json`'s own golden file is unchanged by
        # declaring `Binding` once instead of twice): each aggregate's
        # own emitted IR still lists it, exactly as `given`'s own
        # bare-reference form (`@givens << named`) still lists the SAME
        # rule once per referencing command. "Declared once" is a fact
        # about the SOURCE FILE, never a claim that the wire format's
        # own topology changes.
        def reference_named_chapter_value_object(name, declared_by:)
          verify_resolves_via!("value_object", "Aggregate", "owner_keyed")
          candidates = resolve_owner_keyed(@chapter_value_objects, name)

          built, built_closed_sets =
            if declared_by
              owner = Naming.demodulise(declared_by)
              candidates[owner] ||
                raise(Malformed,
                      "#{@name}'s value_object #{name.inspect} names no value object " \
                      "#{owner} declares in this chapter — #{owner} either hasn't declared " \
                      "#{name.inspect}, or declared_by: named the wrong aggregate")
            elsif candidates.size == 1
              candidates.values.first
            elsif candidates.empty?
              raise(Malformed,
                    "#{@name}'s value_object #{name.inspect} names no value object " \
                    "any aggregate in this chapter has declared yet — declare it once " \
                    "with a block (some aggregate's own value_object(#{name.inspect}) " \
                    "{ ... }), before the aggregates that reference it")
            else
              raise(Malformed,
                    "#{@name}'s value_object #{name.inspect} is ambiguous in this chapter — " \
                    "#{candidates.keys.join(', ')} each declare a DIFFERENT value object under " \
                    "this same name; name which one with declared_by: (e.g. " \
                    "value_object(#{name.inspect}, declared_by: #{candidates.keys.first}))")
            end

          @value_objects << built
          @value_objects.concat(built_closed_sets)
        end
      end
    end
  end
end
