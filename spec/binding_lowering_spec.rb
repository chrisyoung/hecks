require "spec_helper"

# PRD 10 (ADR 0030 Slice 2) — proves canonical `Binding` lowers into an
# executable form without becoming a second source of truth. Every case
# here is shaped after a REAL resolution PolicyInterpreter#trigger_args
# or SagaInterpreter#dispatch_args already performs (policy_interpreter.rb,
# saga_interpreter.rb, both read directly) — synthetic `available_sources`
# inputs standing in for the real payload/correlation/memory hashes those
# interpreters assemble at real dispatch time, per PRD 10's own
# instruction not to wire the real interpreters in this pass.
RSpec.describe Hecksagain::Bluebook::Expression::BindingLowering do
  describe ".lower" do
    it "lowers a literal value to a Literal node, regardless of available sources" do
      lowered = described_class.lower([:status, "frozen"], available_sources: [])

      expect(lowered.destination).to eq(:status)
      expect(lowered.source).to eq(described_class::Literal.new(value: "frozen"))
    end

    it "lowers a Symbol value to a Reference node carrying the given source priority" do
      lowered = described_class.lower([:account, :account_id], available_sources: %i[correlation payload memory])

      expect(lowered.destination).to eq(:account)
      expect(lowered.source).to eq(described_class::Reference.new(name: :account_id, priority: %i[correlation payload memory]))
    end

    it "gives the same canonical binding a different Reference priority for a different context — the context varies, not the lowering" do
      stateless = described_class.lower([:account, :account_id], available_sources: [:payload])
      correlated = described_class.lower([:account, :account_id], available_sources: %i[correlation payload memory])

      expect(stateless.source.priority).to eq([:payload])
      expect(correlated.source.priority).to eq(%i[correlation payload memory])
    end
  end

  describe ".resolve" do
    it "resolves a Literal to itself, untouched by any source" do
      lowered = described_class.lower([:status, "frozen"], available_sources: [])

      expect(described_class.resolve(lowered, {})).to eq([:status, "frozen"])
    end

    # PolicyInterpreter#trigger_args's own shape — a stateless policy has
    # exactly one source, the merged event payload.
    it "resolves a Reference against the one source a stateless policy actually has" do
      lowered = described_class.lower([:account, :account_id], available_sources: [:payload])
      sources = { payload: { account_id: "acct-1" } }

      expect(described_class.resolve(lowered, sources)).to eq([:account, "acct-1"])
    end

    # SagaInterpreter#dispatch_args's own real branch order — correlation
    # head first, THEN payload, THEN memory (saga_interpreter.rb:260-273,
    # read directly). A binding whose name IS the correlation head must
    # win from the correlation bucket even when the SAME name also exists
    # in payload/memory, exactly the way the real 4-branch `if` does.
    it "prefers correlation over payload over memory, in that exact order, when more than one source holds the name" do
      lowered = described_class.lower([:account, :account_id], available_sources: %i[correlation payload memory])
      sources = {
        correlation: { account_id: "from-correlation" },
        payload:     { account_id: "from-payload" },
        memory:      { account_id: "from-memory" }
      }

      expect(described_class.resolve(lowered, sources)).to eq([:account, "from-correlation"])
    end

    it "falls through to payload when correlation does not hold the name" do
      lowered = described_class.lower([:note, :message], available_sources: %i[correlation payload memory])
      sources = { correlation: { account_id: "acct-1" }, payload: { message: "hi" }, memory: {} }

      expect(described_class.resolve(lowered, sources)).to eq([:note, "hi"])
    end

    # dispatch_args's own final `else instance[:memory][value]` — the
    # LAST priority source is the unconditional fallback, answering `nil`
    # on a genuinely absent name rather than refusing, the same as a bare
    # Ruby Hash#[] miss would.
    it "falls all the way through to memory, answering nil rather than refusing, when nothing holds the name" do
      lowered = described_class.lower([:missing, :nowhere], available_sources: %i[correlation payload memory])
      sources = { correlation: {}, payload: {}, memory: {} }

      expect(described_class.resolve(lowered, sources)).to eq([:missing, nil])
    end

    it "raises on a source node lower never produces, rather than silently answering nil" do
      bogus = Struct.new(:whatever).new("x")

      expect { described_class.resolve_source(bogus, {}) }.to raise_error(ArgumentError, /no resolver handles/)
    end
  end
end
