require "hecks"
require "hecks/fuzzing/isolated_boot"

# THE OTHER HALF OF `uses_framework`'s SAFETY STORY — Framework.load!
# attaches whatever a member's own file says right now, live off disk,
# with no version pin of its own (framework.rb's own comment). This
# proves the lock that stands in for one actually gates a boot, not
# just that the two helper methods compute the right numbers in
# isolation.
RSpec.describe "framework.lock" do
  describe Hecks::Framework do
    it "matches every framework member's current content" do
      drift = described_class.drift

      expect(drift[:changed]).to eq({})
      expect(drift[:unlocked]).to eq([])
      expect(drift[:stale]).to eq([])
    end
  end

  describe Hecks::Runtime::Registry::Verification do
    # THE REAL, SHIPPED WIRING — same reasoning
    # governance_authorization_spec.rb already gives for booting
    # examples/banking through IsolatedBoot rather than hand-composing a
    # registry: banking.hecksagon's own `uses_framework "Governance"` /
    # `uses_framework "Identity"` is what actually exercises this gate.
    def boot_banking
      Hecks::Fuzzing::IsolatedBoot.call("examples/banking") { |copy| return Hecks.boot(copy) }
    end

    it "boots cleanly when the lock matches" do
      expect { boot_banking }.not_to raise_error
    end

    it "refuses to boot a domain whose attached framework member has drifted from the lock" do
      allow(Hecks::Framework).to receive(:drift).and_wrap_original do |original|
        real = original.call
        real.merge(changed: { "Governance" => { expected: "a" * 64, actual: "b" * 64 } })
      end

      expect { boot_banking }.to raise_error(Hecks::Runtime::WiringError, /Governance.*changed.*framework\.lock/m)
    end

    it "refuses to boot a domain whose attached framework member has no lock entry at all" do
      allow(Hecks::Framework).to receive(:drift).and_wrap_original do |original|
        real = original.call
        real.merge(unlocked: real[:unlocked] + ["Governance"])
      end

      expect { boot_banking }.to raise_error(Hecks::Runtime::WiringError, /Governance.*no entry/)
    end

    it "stays quiet about a framework member this boot never attached" do
      allow(Hecks::Framework).to receive(:drift).and_wrap_original do |original|
        real = original.call
        real.merge(changed: { "Compliance" => { expected: "a" * 64, actual: "b" * 64 } })
      end

      expect { boot_banking }.not_to raise_error
    end
  end
end
