require "spec_helper"

# Real coverage for redirects_native's own corpus consumer: the DSL
# builder (item 1855be0-m) and the IR/contracts/self-hosted-grammar side
# (item 05) both landed with nothing in the judged corpus actually
# CALLING redirects_native -- "a verb the judge is never OFFERED cannot
# prove the mechanism works, only that it parses" (docs/hecks-migration-
# findings.md). Banking's Account.Freeze now carries `redirects_native
# "ComplianceHold"`, closing spec/judge_coverage_spec's "offers every verb
# the language declares" (Bluebook::Command.Redirect was declared but
# never offered) and spec/plan_spec's own append-table assertion (a sixth
# appendable list, derived automatically from the grammar, not hand-kept).
RSpec.describe "redirects_native's real corpus consumer" do
  def banking_bluebook
    registry = Hecksagain::Runtime::Registry.new
    Hecksagain.with_registry(registry) do
      Kernel.load(InMemoryDomain::PERSISTENCE_PORT)
      Kernel.load(InMemoryDomain::EXTRACTION_PORT)
      Kernel.load(InMemoryDomain::MEMORY_ADAPTER)
      Kernel.load(InMemoryDomain::PRISM_ADAPTER)
      Kernel.load(File.join(InMemoryDomain::ROOT, "examples/banking/bluebook/banking.bluebook"))
    end
    registry.bluebook("Banking")
  end

  it "Account.Freeze declares redirects_native ComplianceHold" do
    freeze = banking_bluebook.aggregate("Account").commands.find { |c| c.hecks_name == "Freeze" }
    # Two tools, not one (item 39, migration plan task 4) — a corpus that
    # only ever fills a list-shaped field once is indistinguishable from
    # a scalar, spec/plurality_coverage_spec's own concern.
    expect(freeze.redirects_native).to include("ComplianceHold")
  end

  it "the self-hosted grammar's Judge now offers Bluebook::Command.Redirect" do
    plan = Hecksagain::Bluebook::MetaValidator::Plan.for(Hecksagain::Bluebook::MetaValidator.grammar_registry)
    expect(plan.verbs).to include("Bluebook::Command.Redirect")
  end

  it "the append table includes redirects_native alongside the other five appendable lists" do
    plan = Hecksagain::Bluebook::MetaValidator::Plan.for(Hecksagain::Bluebook::MetaValidator.grammar_registry)
    appends = plan.category("Command").appends
    expect(appends.keys).to include("redirects_native")
  end
end
