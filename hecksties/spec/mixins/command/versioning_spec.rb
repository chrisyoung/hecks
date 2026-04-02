require "spec_helper"

RSpec.describe "Optimistic concurrency — version check on commands" do
  before(:all) do
    @domain = Hecks.domain "VersionCheckTest" do
      aggregate "Document" do
        attribute :title, String

        command "CreateDocument" do
          attribute :title, String
        end

        command "RenameDocument" do
          reference_to "Document"
          attribute :title, String
          attribute :expected_version, Integer
        end

        command "UpdateDocument" do
          reference_to "Document"
          attribute :title, String
        end
      end
    end

    @app = Hecks.load(@domain, force: true)
  end

  it "new aggregates start at version 0" do
    doc = VersionCheckTestDomain::Document.create(title: "Draft")
    expect(doc.aggregate.version).to eq(0)
  end

  it "bumps version when expected_version matches" do
    doc = VersionCheckTestDomain::Document.create(title: "Draft")
    result = VersionCheckTestDomain::Document.rename(
      document: doc.id, title: "Final", expected_version: 0
    )
    expect(result.aggregate.version).to eq(1)
  end

  it "raises ConcurrencyError when expected_version mismatches" do
    doc = VersionCheckTestDomain::Document.create(title: "Draft")
    # First rename bumps to version 1
    VersionCheckTestDomain::Document.rename(
      document: doc.id, title: "v1", expected_version: 0
    )
    # Second rename with stale version 0 should fail
    expect {
      VersionCheckTestDomain::Document.rename(
        document: doc.id, title: "v2", expected_version: 0
      )
    }.to raise_error(Hecks::ConcurrencyError, /expected 0, got 1/)
  end

  it "skips version check when expected_version is not on the command" do
    doc = VersionCheckTestDomain::Document.create(title: "Draft")
    result = VersionCheckTestDomain::Document.update(
      document: doc.id, title: "Updated"
    )
    expect(result.aggregate).not_to be_nil
    expect(result.aggregate.version).to eq(0)
  end

  it "ConcurrencyError includes structured context" do
    doc = VersionCheckTestDomain::Document.create(title: "Draft")
    VersionCheckTestDomain::Document.rename(
      document: doc.id, title: "v1", expected_version: 0
    )

    begin
      VersionCheckTestDomain::Document.rename(
        document: doc.id, title: "v2", expected_version: 0
      )
    rescue Hecks::ConcurrencyError => e
      expect(e.expected_version).to eq(0)
      expect(e.actual_version).to eq(1)
      expect(e.aggregate_id).to eq(doc.id)
      json = e.as_json
      expect(json[:expected_version]).to eq(0)
      expect(json[:actual_version]).to eq(1)
    end
  end

  it "successive bumps increment version correctly" do
    doc = VersionCheckTestDomain::Document.create(title: "v0")
    VersionCheckTestDomain::Document.rename(
      document: doc.id, title: "v1", expected_version: 0
    )
    result = VersionCheckTestDomain::Document.rename(
      document: doc.id, title: "v2", expected_version: 1
    )
    expect(result.aggregate.version).to eq(2)
  end
end
