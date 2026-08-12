require_relative "../../naming"
require_relative "../errors"
require_relative "../refusal_wording"

module Hecksagain
  module Runtime
    class EntityInterpreter
      # The payload gate — same contract as CommandInterpreter::ArgumentGate
      # (a command takes the arguments it declares, all of them, and no
      # others), but an entity command is addressed through TWO identities at
      # once: the parent aggregate's (read by `parent`) and the entity's own
      # (read by `element_of`). Both sets of heads are legitimate addressing
      # keys, not attributes, and `:id` sugars the parent lookup the same way
      # it does on the aggregate path.
      #
      # This was missing entirely — DISPATCH_ORDER's own comment claimed "an
      # entity inherits its aggregate's own gate," but nothing on the entity
      # dispatch path ever ran one. An unknown argument rode along untouched;
      # a declared-but-absent one resolved to `nil` and silently overwrote
      # whatever the stored attribute held. See docs/audits — H1.
      module ArgumentGate
        private

        def refuse_unknown_arguments(aggregate, entity, command, args)
          addressing = [:id, *aggregate.identity_heads, *entity.identity_heads]
          known      = (command.attributes.map(&:name) + addressing).compact.map(&:to_sym)
          # SORTED — refusal wording is contract, pinned byte-for-byte by the
          # corpus, so it cannot depend on hash iteration order. Same
          # reasoning as CommandInterpreter::ArgumentGate.
          unknown = (args.keys.map(&:to_sym) - known).sort
          return if unknown.empty?

          raise UnknownArgument,
                RefusalWording.render("UnknownArgument", "unknown_args",
                                      command: command.hecks_name, unknown: unknown.join(", "),
                                      declared: command.attributes.map(&:name).join(", "))
        end

        # Identical rule and identical wording key to the aggregate path —
        # what counts as "required" doesn't depend on how the command is
        # addressed, only on its own declared attributes.
        def refuse_absent_arguments(command, args)
          given    = args.keys.map(&:to_sym)
          required = command.attributes.reject(&:optional?).map { |attribute| attribute.name.to_sym }
          absent = (required - given).sort
          return if absent.empty?

          raise AbsentArgument,
                RefusalWording.render("AbsentArgument", "absent_args",
                                      command: command.hecks_name, absent: absent.join(", "),
                                      declared: command.attributes.map(&:name).join(", "))
        end
      end
    end
  end
end
