require "spec_helper"

# A reaction has two ways to not happen, and they are not the same thing.
#
# The domain REFUSING (a given not met, a lifecycle move not admitted, a
# cross-domain target not loaded in this deployment) is a fact worth recording :
# the command that emitted the event still stands, and the log says why.
#
# The runtime BREAKING (a NoMethodError in an interpreter, a NameError from a
# missing constant) is a defect. It once had two wrong homes in a row : first
# a blanket `rescue StandardError` that wrote it as `delivered: false` beside
# every legitimate refusal, so a crashed runtime read as normal operation ;
# then, after that was narrowed to DOMAIN_REFUSALS alone, nothing caught it at
# all, so it propagated straight through the ALREADY-SUCCEEDED triggering
# command's own `dispatch` call and blew that up too. Neither is right : a
# defect is now caught (so the triggering command's success stands), but
# recorded distinguishably (`defect: true`, the error's own class) rather than
# folded into an ordinary refusal's shape, and warned to STDERR so it is never
# silent.
RSpec.describe "a reaction that cannot be delivered" do
  let(:event) do
    Hecksagain::Runtime::Event.new(
      name: "Rang", aggregate: "Reflex::Echo", id: "bell-1",
      payload: {}, occurred_at: Time.now.utc.iso8601
    )
  end

  let(:policy) do
    Hecksagain::Bluebook::Policy.new(
      name: "ReactToRing", on_event: "Rang", trigger_command: "Echo.Ring"
    )
  end

  # A door that fails the way the thing behind it fails.
  def door_raising(error)
    Class.new do
      define_method(:reaction_depth_reached?) { false }
      define_method(:max_reaction_depth) { 8 }
      define_method(:reenter) { |*, **| raise error }
    end.new
  end

  # A door that fails `failures` times, then succeeds — for proving retry
  # actually re-attempts the SAME dispatch rather than merely tolerating a
  # first failure differently.
  def door_failing_then_succeeding(error, failures:)
    Class.new do
      attr_reader :attempts

      define_method(:initialize) { @attempts = 0 }
      define_method(:reaction_depth_reached?) { false }
      define_method(:max_reaction_depth) { 8 }
      define_method(:reenter) do |*, **|
        @attempts += 1
        raise error if @attempts <= failures
      end
    end.new
  end

  def registry_for(policy)
    bluebook = Struct.new(:name, :policies).new("Reflex", [policy])
    Class.new do
      attr_reader :reaction_log

      define_method(:initialize) { @reaction_log = [] }
      define_method(:bluebook) { |_domain| bluebook }
      define_method(:bluebooks) { { "Reflex" => bluebook } }
    end.new
  end

  it "RECORDS a refusal by the domain — the emitting command still stands" do
    registry = registry_for(policy)
    interpreter = Hecksagain::Runtime::PolicyInterpreter.new(
      registry, door: door_raising(Hecksagain::Runtime::GivenNotMet.new("bell already rung"))
    )

    expect { interpreter.react(event, "Reflex") }.not_to raise_error
    expect(registry.reaction_log.first).to include(delivered: false, reason: "bell already rung")
  end

  it "RECORDS a defect in the runtime, distinguishably, rather than raising or logging it as a refusal" do
    registry = registry_for(policy)
    interpreter = Hecksagain::Runtime::PolicyInterpreter.new(
      registry, door: door_raising(NoMethodError.new("undefined method `boom'"))
    )

    expect { interpreter.react(event, "Reflex") }.to output(/ReactToRing.*Rang.*boom/m).to_stderr
    expect(registry.reaction_log.first).to include(
      delivered: false, reason: "undefined method `boom'", defect: true, error_class: "NoMethodError"
    )
  end

  # ADR 0029's own recorded "Open" item, closed: a stateless policy now
  # retries a crash the same MAX_DEFECT_RETRIES times a saga's own dispatch
  # already does, before treating it as a defect — the transient-failure
  # reasoning (a DB timeout, a race, a cold start clearing on its own)
  # named nothing specific to correlation or memory, so a policy gets it
  # too.
  it "RETRIES a crash up to MAX_DEFECT_RETRIES times, and delivers cleanly once it clears" do
    registry = registry_for(policy)
    door = door_failing_then_succeeding(NoMethodError.new("undefined method `boom'"),
                                        failures: Hecksagain::Runtime::PolicyInterpreter::MAX_DEFECT_RETRIES)
    interpreter = Hecksagain::Runtime::PolicyInterpreter.new(registry, door: door)

    expect { interpreter.react(event, "Reflex") }.not_to output.to_stderr
    expect(registry.reaction_log.first).to include(delivered: true)
    expect(door.attempts).to eq(Hecksagain::Runtime::PolicyInterpreter::MAX_DEFECT_RETRIES + 1)
  end

  it "gives up as a defect only once every retry is exhausted, naming the real attempt count" do
    registry = registry_for(policy)
    door = door_raising(NoMethodError.new("undefined method `boom'"))
    interpreter = Hecksagain::Runtime::PolicyInterpreter.new(registry, door: door)

    expected_attempts = Hecksagain::Runtime::PolicyInterpreter::MAX_DEFECT_RETRIES + 1
    expect { interpreter.react(event, "Reflex") }.to output(/after #{expected_attempts} attempts/).to_stderr
    expect(registry.reaction_log.first).to include(delivered: false, defect: true, error_class: "NoMethodError")
  end

  # `deliver_for_each_row` — previously the one dispatch path with NO
  # defect handling of its own at all : a crash in ONE row propagated out
  # of the whole `Array(rows).map` in `deliver_for_each` and was caught by
  # THAT method's own outer rescue as a single aggregate defect for the
  # entire fan-out, discarding whatever other rows had already succeeded.
  # Now isolated and retried per row, the same as `deliver`'s own
  # singleton path and a saga's own per-leg dispatch — exercised directly
  # (a private method, `send`) since building a full for_each/query
  # fixture just to inject one row's crash would test the query machinery
  # `spec/runtime/policy_spec.rb`'s own real-domain fixtures already cover,
  # not this method's own new retry/isolation logic.
  describe "#deliver_for_each_row" do
    let(:base_record) { { policy: "ReviewOnFlag", on: "Flagged", trigger: "Fanout::Account.Review" } }

    it "retries a crashing row up to MAX_DEFECT_RETRIES times, and delivers cleanly once it clears" do
      registry = registry_for(policy)
      door = door_failing_then_succeeding(NoMethodError.new("undefined method `boom'"),
                                          failures: Hecksagain::Runtime::PolicyInterpreter::MAX_DEFECT_RETRIES)
      interpreter = Hecksagain::Runtime::PolicyInterpreter.new(registry, door: door)

      row_record = interpreter.send(:deliver_for_each_row, "Fanout::Account.Review", base_record, {}, id: "a1")

      expect(row_record).to include(delivered: true, for_row: "a1")
      expect(door.attempts).to eq(Hecksagain::Runtime::PolicyInterpreter::MAX_DEFECT_RETRIES + 1)
    end

    it "isolates a row that never clears as its own defect, distinguishably, without touching sibling rows" do
      registry = registry_for(policy)
      door = door_raising(NoMethodError.new("undefined method `boom'"))
      interpreter = Hecksagain::Runtime::PolicyInterpreter.new(registry, door: door)

      expected_attempts = Hecksagain::Runtime::PolicyInterpreter::MAX_DEFECT_RETRIES + 1
      row_record = nil
      expect { row_record = interpreter.send(:deliver_for_each_row, "Fanout::Account.Review", base_record, {}, id: "a1") }
        .to output(/ReviewOnFlag.*Flagged.*a1.*after #{expected_attempts} attempts/m).to_stderr

      expect(row_record).to include(delivered: false, for_row: "a1", defect: true, error_class: "NoMethodError")
    end
  end
end
