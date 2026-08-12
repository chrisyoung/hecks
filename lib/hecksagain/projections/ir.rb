# Required here as well as from `projections.rb`, which already loads this
# first: `spec/load_hygiene_spec.rb` loads every lib file STANDALONE in a
# fresh process, and a target that only works when something else was loaded
# before it is a load-order dependency waiting to bite. Not circular —
# `projector.rb` deliberately does not require the targets back, which is the
# loop its own note is guarding against.
require_relative "../projector"

module Hecksagain
  module Projections
    # The canonical IR, as a constant. The implementation already existed
    # and is already golden-tested (`Projector::IRProjector`, registered
    # as `:ir`) — this only gives it the constant spelling every other
    # target has, by re-registering the SAME module under the same key.
    #
    # Deliberately not a new implementation: two things named `IR` that
    # each rendered IR their own way is exactly the drift this namespace
    # exists to avoid.
    IR = Projector::IRProjector

    IR.extend(Projector::Target)
    IR.projects_as :ir
  end
end
