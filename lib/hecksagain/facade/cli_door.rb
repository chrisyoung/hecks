require_relative "../runtime/errors"

module Hecksagain
  module Facade
    # THE CLI DOOR — WHERE Facade MEETS A CALLER HOLDING FLAT STRINGS.
    #
    # `JsonDoor` beside this one translates for a caller holding parsed JSON:
    # String keys, already-nested objects, real Integers. A command line has
    # neither of those. It has `sequence.value=99` — one flat string, with the
    # nesting spelled as a path and the type not spelled at all.
    #
    # So this does the two things that turns into: rebuild the nesting, and
    # give every leaf the type the chapter declared for it.
    #
    # THE TYPE COMES FROM THE PROJECTION, NEVER FROM THE VALUE. A door that
    # guessed — "99 looks like a number" — would send the Integer 99 for a
    # version string of "99", and be wrong in a way nothing downstream could
    # detect, because both are perfectly good arguments. `Projector::CliProjector`
    # already read the declared field type out of the value object; this only
    # applies it.
    module CliDoor
      module_function

      # `["reference.value=BUG#1", "sequence.value=99"]` against a projected
      # verb spec -> `{ reference: { value: "BUG#1" }, sequence: { value: 99 } }`
      def arguments(spec, pairs)
        options = spec[:arguments].to_h { |argument| [argument[:path], argument] }

        pairs.each_with_object({}) do |pair, args|
          path, value = split(pair)
          argument    = options[path] || options[expand(path, options)] ||
                        raise(Runtime::NotFound, unknown(path, options.keys))

          bury(args, (options.key?(path) ? path : expand(path, options)).split("."), cast(value, argument[:type]))
        end
      end

      def split(pair)
        name, value = pair.split("=", 2)
        raise Runtime::NotFound, "#{pair.inspect} is not name=value" if value.nil?

        [name, value]
      end

      # THE SHORT FORM, FOR THE COMMON CASE. Almost every value object in this
      # corpus has exactly one field, so `reference=BUG#1` is unambiguous and
      # is what anybody types. Expanded only when precisely one option starts
      # with that prefix — two would be a guess, and a guess about which field
      # a caller meant is worse than asking them to say.
      def expand(path, options)
        candidates = options.keys.select { |key| key.start_with?("#{path}.") }
        candidates.length == 1 ? candidates.first : path
      end

      def cast(value, type)
        case type
        when "Integer" then Integer(value)
        when "Float"   then Float(value)
        when "Boolean" then %w[true yes 1].include?(value.downcase)
        else value
        end
      rescue ArgumentError
        raise Runtime::TypeMismatch, "#{value.inspect} is not #{type} — the chapter declares this field as #{type}"
      end

      def bury(hash, path, value)
        *branches, leaf = path.map(&:to_sym)
        target = branches.reduce(hash) { |node, key| node[key] ||= {} }
        target[leaf] = value
        hash
      end

      def unknown(path, known)
        "no argument #{path.inspect} — this verb takes #{known.sort.join(', ')}"
      end
    end
  end
end
