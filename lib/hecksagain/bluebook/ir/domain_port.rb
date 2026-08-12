module Hecksagain
  module Bluebook
    module IR
      # THE PRIMARY/DRIVING HALF OF HEXAGONAL ARCHITECTURE (Cockburn) — called
      # BY an adapter living outside the bluebook entirely, never by the
      # domain calling out. That is already `Hecks.port` (persistence,
      # projection, extraction, loading) plus `Ports::*` : the secondary/
      # driven half, unchanged by this.
      #
      # An operation carries no `given`/`ensures`/`then_set` — a port is the
      # anti-corruption boundary that turns an external call into a fact in
      # this domain's own vocabulary, not a second place business rules live.
      # Those stay on whatever command a `policy` triggers in reaction to the
      # event an operation emits.
      class PortOperation
        attr_reader :hecks_name, :attributes, :emits, :direction, :answers, :refuses

        # TWO DIRECTIONS THROUGH ONE DOOR.
        #
        # `:inbound` is what this class has always been — `tells`, spelled
        # `operation` before it had a twin: an external fact arriving, turned
        # into this domain's own event. It emits and that is all; there is no
        # channel back to whoever called.
        #
        # `:outbound` is `asks` — the domain wanting something from outside
        # and having to live with either answer. It names BOTH: `answers` for
        # what the adapter came back with, `refuses` for what it said instead.
        # Naming only the happy one would put the failure somewhere the model
        # cannot see, which is the whole reason a boundary is worth modelling.
        def initialize(name:, attributes: [], emits: [], direction: :inbound, answers: nil, refuses: nil)
          @hecks_name = name.to_s
          @attributes = attributes
          @emits      = emits
          @direction  = direction.to_sym
          @answers    = answers
          @refuses    = refuses
          @attributes_by_name = attributes.to_h { |attribute| [attribute.name, attribute] }
        end

        def outbound? = @direction == :outbound
        def inbound?  = @direction == :inbound

        # No root reference of its own — unlike a command, every attribute
        # EQUALLY describes the payload, including whichever one identifies
        # the record its emitted event belongs to. Kept only so
        # CommandInterpreter::ArgumentGate's `reference_key` can ask for it
        # without learning this isn't a command.
        def references = nil

        def attribute(named) = @attributes_by_name[named.to_sym]

        # THE ATTRIBUTE THAT SAYS WHICH RECORD THIS OPERATION IS ABOUT — a
        # reference attribute targeting the aggregate that owns this port.
        # Required at build time (PortOperationBuilder#build) precisely so
        # this never comes back nil at dispatch: an operation with no such
        # attribute could emit an event naming no record at all.
        def identity_attribute(owner_name)
          @attributes.find { |attribute| attribute.reference? && attribute.type.target_name == owner_name.to_s }
        end

        # `direction` IS ALWAYS EMITTED, but `answers`/`refuses` only when
        # there is one — an inbound operation carrying two null keys would
        # change every golden IR fixture in the corpus for a fact it does not
        # have.
        def to_h
          shape = { name: @hecks_name, attributes: @attributes.map(&:to_h), emits: @emits, direction: @direction }
          shape[:answers] = @answers if @answers
          shape[:refuses] = @refuses if @refuses
          shape
        end
      end

      # A named group of operations an aggregate (or, later, a chapter)
      # exposes to whatever adapter calls in — the contract that today lives
      # only as a bare `verb`/`signal` pair in a standalone `.port` file.
      # Superseding those is the goal ; for now they keep working untouched,
      # and this is additive.
      class DomainPort
        attr_reader :name, :operations

        def initialize(name:, operations: [])
          @name       = name.to_s
          @operations = operations
        end

        def operation(named) = @operations.find { |op| op.hecks_name == named.to_s }

        def to_h
          { name: @name, operations: @operations.map(&:to_h) }
        end
      end
    end
  end
end
