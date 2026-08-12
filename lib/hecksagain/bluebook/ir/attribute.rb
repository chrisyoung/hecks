require_relative "../../naming"

module Hecksagain
  module Bluebook
    module IR
      class Attribute
        attr_reader :name, :type, :default, :pattern, :admits

        # A Reference is kept AS ITSELF. Every other type is still a name, and
        # crosses over as its construct does.
        #
        # `admits` names an ALREADY-DECLARED closed set the value must belong
        # to — `Vocabulary::QueryComparator` — spelled aggregate-qualified
        # because the set is a value object INSIDE an aggregate, and the
        # aggregate is the only thing `reference_to` can reach.
        #
        # ON THE WIRE, because it is a RULE and not only a typing hint.
        #
        # It began as neither. The link existed so a generator could type
        # `WhereClause.op` as `WhereOp` — a typing convenience, not worth
        # moving 710 attribute records across eight goldens for. Then `admits`
        # grew teeth (coercion refuses a non-member) and the argument
        # inverted: a rule the wire does not carry is one a reader of the IR
        # cannot enforce, and a bluebook whose meaning depends on the reader
        # means two things. Proved rather than assumed — the same domain
        # refused "burnt" through one reading and emitted the event through
        # another.
        #
        # The wire carries the NAME, not the members. A reader resolves it
        # against the IR it holds, so the members are declared once and
        # copied nowhere — which is the same reason `admits` exists at all.
        def initialize(name:, type:, list: false, default: nil, optional: false, pattern: nil,
                       admits: nil)
          @name     = name.to_sym
          @type     = spell(type)
          @list     = list
          @default  = default
          @optional = optional
          @pattern  = pattern
          @admits   = admits&.to_s
        end

        # A BARE CONSTANT IN A BLUEBOOK IS A NAME, EVEN WHEN RUBY HAS HEARD OF IT.
        #
        # `BluebookBuilder.build` says exactly this and installs a `const_missing`
        # resolver that hands back the symbol — `attribute :target, Target` becomes
        # the name "Target" and nothing looks Target up. That works only while the
        # lookup FAILS, and `Facade::Surface` installs every aggregate name as a
        # TOP-LEVEL constant (its own comment, and `ConstShim`'s, both say so).
        #
        # So in one process: boot a domain with an aggregate named `Target`, then
        # load a chapter whose own value object is called `Target`, and Ruby
        # resolves the constant before the hook is ever asked. The chapter is then
        # built against somebody else's aggregate — silently, with no refusal —
        # and the attribute stops meaning what the file plainly says.
        #
        # It was found by two grammar chapters that each declare `value_object
        # "Target"`: with `QualityControl` (which has an `aggregate "Target"`)
        # booted first, `Expression:Operator:Render#attributes[0]` turned into a
        # cross-aggregate reference and the meta-domain refused the chapter for
        # naming an aggregate that does not exist. Nothing about the failure
        # pointed here, and it moved with spec ORDER, which is what a shared
        # top-level namespace does to a language embedded in Ruby.
        #
        # DEMODULISED, so both paths spell it the same: `:Target` and
        # `QualityControl::Target` are both "Target". A plain class stays itself —
        # `String` demodulises to "String" — so the ordinary case is untouched.
        # This does not undo the constant leak; it makes the leak unable to change
        # what a chapter MEANS, which is the part that has to hold.
        def spell(type)
          return type if type.is_a?(Reference)
          return Naming.demodulise(type) if type.is_a?(Module)

          type.to_s
        end

        def list?   = @list
        def scalar? = !@list
        def reference? = @type.is_a?(Reference)

        # MAY THIS FACT BE LEFT OUT?
        #
        # Required is the default and by far the common case — a command takes
        # the arguments it declares, and all of them — so the EXCEPTION is what
        # gets marked. Marking the other way would annotate almost every
        # attribute in the corpus to say nothing.
        #
        # Only a COMMAND enforces this. An aggregate's own attributes are filled
        # by the commands that set them, and a value object's by its
        # constructor ; neither is a payload anyone hands in.
        def optional? = @optional

        # Held because a declared vocabulary pins it — spec/vocabulary_conformance
        # holds `Primitive`'s members to this list. The `primitive?` predicate that
        # used to read it had no caller anywhere and is gone.
        PRIMITIVES = %w[String Integer Float TrueClass FalseClass].freeze

        # `type` is spelled, never handed over. A Reference renders as
        # "Reference<Customer>" here because that is the export's pinned spelling.
        def to_h
          { name: @name, type: @type.to_s, list: @list, default: @default, optional: @optional,
            pattern: @pattern, admits: @admits }
        end
      end
    end
  end
end
