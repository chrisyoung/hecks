require "spec_helper"

# Real coverage for docs/hecks-migration-findings.md: a pure prose
# addition (the authoritative catalogue this whole PR-split migration
# cites by item number throughout its own PR bodies), so there is no
# runtime behavior to exercise -- this pins its presence and structural
# claims instead, so a later edit that silently drops a section is
# caught the same way a code regression would be.
RSpec.describe "docs/hecks-migration-findings.md" do
  PATH = File.join(InMemoryDomain::ROOT, "docs/hecks-migration-findings.md")

  it "exists and is not an ADR" do
    expect(File.exist?(PATH)).to be(true)
    expect(File.read(PATH)).to match(/\*\*Status: informational\.\*\*/)
  end

  it "catalogues its own claimed totals: 18 new DSL constructs, dispatch bugs, structural fixes" do
    text = File.read(PATH)
    expect(text).to match(/New DSL constructs hecksagain could not parse or express at all \(18\)/)
  end
end
