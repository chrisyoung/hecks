# PRD 10 (ADR 0030 Slice 2) — lowers a canonical `Binding` pair
# (`[key, value]`, the shape `Behaviour::Policy#with_spec`/
# `Behaviour::ProcessManager::DispatchSpec#with_spec` already hold —
# policy.rb/process_manager.rb, read directly) into an EXECUTABLE form
# that names its resolution strategy as data, rather than leaving it
# implicit in which interpreter method happens to run.
#
# THE REAL PROBLEM THIS CLOSES. `PolicyInterpreter#trigger_args`
# (policy_interpreter.rb) and `SagaInterpreter#dispatch_args`
# (saga_interpreter.rb) each independently branch on `value.is_a?(Symbol)`
# and then, for a saga, on which of THREE named sources — the
# correlation head, the event payload, or accumulated memory — happens
# to hold the key, tried in that fixed order. That priority order is
# real, load-bearing behaviour, and until now it existed only as
# procedural Ruby, duplicated once per interpreter, with zero
# representation in Rust at all.
#
# THE ONE THING THIS FILE DELIBERATELY DOES NOT KNOW. It has no idea
# what a "correlation head" or "saga memory" IS — that's a
# `Reaction`/`ReactionContext` concern (ADR 0030 Slice 3), explicitly
# out of scope here. `lower`/`resolve` below take an ORDERED LIST OF
# NAMED SOURCE BUCKETS (`available_sources`) as a plain argument — a
# stateless policy passes `[:payload]`; a correlated process-manager leg
# would pass `[:correlation, :payload, :memory]`, with `:correlation`
# itself just a one-entry bucket keyed by whatever the process manager's
# own `correlates_by` field is named. Assembling THAT bucket correctly
# is the future caller's job, not this file's — which is exactly what
# keeps this lowering pure and testable with synthetic sources, per PRD
# 10's own Non-goals.
module Hecksagain
  module Bluebook
    module Expression
      module BindingLowering
        # The executable form. `source` is one of the two node kinds
        # below — deliberately not a third bespoke resolution language:
        # PRD 09's own `Expression` algebra already models "a literal" vs
        # "something that must be looked up," and reusing that
        # distinction here (rather than inventing a Binding-specific one)
        # is what ADR 0030 predicted `Expression` would turn out to be —
        # the one substrate several different constructs share.
        ExecutableBinding = Struct.new(:destination, :source, keyword_init: true)

        # A binding whose canonical `value` was not a Symbol — carried
        # through unchanged, resolved to itself regardless of context.
        Literal = Struct.new(:value, keyword_init: true)

        # A binding whose canonical `value` WAS a Symbol — `name` is that
        # symbol; `priority` is the ordered list of source-bucket names to
        # search, first match wins, exactly mirroring `dispatch_args`'s
        # own real branch order for whichever sources this reaction
        # actually has. Two policies with different available sources
        # (stateless vs. correlated) lower the SAME canonical binding to
        # a DIFFERENT `Reference.priority` — the context varies, the
        # lowering function does not.
        Reference = Struct.new(:name, :priority, keyword_init: true)

        module_function

        # `binding` is a `[key, value]` pair — `with_spec`'s own real
        # element shape (policy.rb:19, process_manager.rb:14, both read
        # directly: `with_spec.map { |key, value| ... }`), not a bespoke
        # wrapper type. `available_sources` is frozen into the lowered
        # `Reference` rather than re-read at resolve time — the ORDER a
        # binding searches sources in is fixed once lowered, the same way
        # `dispatch_args`'s own branch order is fixed in the interpreter
        # code that runs it, not re-decided per call.
        def lower(binding, available_sources:)
          key, value = binding
          source = if value.is_a?(Symbol)
                     Reference.new(name: value, priority: available_sources)
                   else
                     Literal.new(value: value)
                   end
          ExecutableBinding.new(destination: key.to_sym, source: source)
        end

        # Resolves ONE executable binding against a real `sources` map
        # (`{payload: {...}, correlation: {...}, memory: {...}}` — only
        # the buckets this binding's own `priority` names are ever read).
        # Returns `[destination, value]`, the same pair shape
        # `trigger_args`/`dispatch_args`'s own `to_h` block produces.
        def resolve(executable_binding, sources)
          [executable_binding.destination, resolve_source(executable_binding.source, sources)]
        end

        def resolve_source(source, sources)
          case source
          when Literal then source.value
          when Reference then resolve_reference(source, sources)
          else
            # Every node `lower` can produce has a `when` above — the
            # same "no silent nil" backstop Evaluator#interpret and
            # Resolver#interpret already hold themselves to (see their
            # own trailing-arm comments) — a missing case here would
            # otherwise read as "this binding resolved to nil" instead of
            # "this lowering produced a node nothing can resolve."
            raise ArgumentError, "no resolver handles #{source.class} — add a case before lower can produce it"
          end
        end

        # First bucket in `priority` that actually HOLDS `name` wins —
        # `dispatch_args`'s own real order (correlation head, then
        # payload, then memory). The LAST bucket in `priority` is the
        # unconditional fallback if none matched, mirroring
        # `dispatch_args`'s own final `else instance[:memory][value]` —
        # a plain Hash `#[]` on an absent key answers `nil` there, not a
        # refusal, so this does the same rather than raising on a
        # genuinely-absent name.
        def resolve_reference(reference, sources)
          reference.priority.each do |bucket_name|
            bucket = sources[bucket_name]
            next unless bucket.is_a?(Hash) && bucket.key?(reference.name)

            return bucket[reference.name]
          end

          sources.dig(reference.priority.last, reference.name)
        end
      end
    end
  end
end
