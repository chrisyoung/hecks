require_relative "bluebook/grammar"
require_relative "bluebook/tokenizer"

# BlueBook
#
# The domain command language for Hecks. Named for Evans' DDD Blue Book
# and Smalltalk's Blue Book — the two traditions this grammar descends from.
#
# Parses domain modeling commands into structured ASTs. No eval — the grammar
# defines what's expressible, and anything outside the grammar is rejected.
#
#   ast = BlueBook::Grammar.parse("Pizza.attr :name, String")
#   # => { target: "Pizza", method: "attr", args: [:name], kwargs: {}, type_args: [String] }
#
module BlueBook
  VERSION = "2026.03.29.1"
end
