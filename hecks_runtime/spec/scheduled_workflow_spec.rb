require "spec_helper"

RSpec.describe "Scheduled workflows" do
  it "parses schedule from DSL" do
    domain = Hecks.domain "ScheduleTest" do
      aggregate "License" do
        attribute :holder, String
        attribute :expired, String

        command "CreateLicense" do
          attribute :holder, String
        end

        command "RevokeLicense" do
          attribute :license_id, String
        end

        specification "Expired" do |license|
          license.expired == "yes"
        end
      end

      workflow "PeriodicCleanup" do
        schedule "daily"

        step "revoke_expired" do
          find "License", spec: "Expired"
          trigger "RevokeLicense"
        end
      end
    end

    wf = domain.workflows.first
    expect(wf.name).to eq("PeriodicCleanup")
    expect(wf.schedule).to eq("daily")
    expect(wf.scheduled?).to be true
    expect(wf.steps.size).to eq(1)

    step = wf.steps.first
    expect(step[:name]).to eq("revoke_expired")
    expect(step[:find_aggregate]).to eq("License")
    expect(step[:find_spec]).to eq("Expired")
    expect(step[:trigger]).to eq("RevokeLicense")
  end

  it "non-scheduled workflows have no schedule" do
    domain = Hecks.domain "NoSchedule" do
      aggregate "Task" do
        attribute :name, String
        command "CreateTask" do
          attribute :name, String
        end
      end

      workflow "SimpleFlow" do
        step "CreateTask"
      end
    end

    wf = domain.workflows.first
    expect(wf.schedule).to be_nil
    expect(wf.scheduled?).to be false
  end

  it "mixes regular steps with scheduled steps" do
    domain = Hecks.domain "MixedWf" do
      aggregate "Item" do
        attribute :name, String
        command "CreateItem" do
          attribute :name, String
        end
        command "ArchiveItem" do
          attribute :item_id, String
        end
        specification "Stale" do |item|
          true
        end
      end

      workflow "Cleanup" do
        schedule "weekly"
        step "CreateItem"
        step "archive_stale" do
          find "Item", spec: "Stale"
          trigger "ArchiveItem"
        end
      end
    end

    wf = domain.workflows.first
    expect(wf.steps.size).to eq(2)
    expect(wf.steps[0][:command]).to eq("CreateItem")
    expect(wf.steps[1][:find_aggregate]).to eq("Item")
  end
end
