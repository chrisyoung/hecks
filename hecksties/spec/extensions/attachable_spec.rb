require "spec_helper"
require "hecks/extensions/attachable"

RSpec.describe "Hecks::Attachable" do
  let(:domain) do
    Hecks.domain "AttachTest" do
      aggregate "Patient" do
        attribute :name, String
        command "CreatePatient" do
          attribute :name, String
        end
      end
    end
  end

  let(:hecksagon) do
    Hecks.hecksagon do
      aggregate "Patient" do
        avatar.attachable
      end
    end
  end

  before do
    @app = Hecks.load(domain, hecksagon: hecksagon)
  end

  after do
    Hecks.last_hecksagon = nil
    Object.send(:remove_const, :AttachTestDomain) if defined?(AttachTestDomain)
  end

  describe "attach and list" do
    it "attaches metadata and lists attachments" do
      patient = Patient.create(name: "Alice")
      Patient.attach_avatar(patient.id, filename: "photo.jpg", content_type: "image/jpeg")

      attachments = Patient.avatar_attachments(patient.id)
      expect(attachments.size).to eq(1)
      expect(attachments.first[:filename]).to eq("photo.jpg")
      expect(attachments.first[:content_type]).to eq("image/jpeg")
      expect(attachments.first[:ref_id]).to be_a(String)
    end

    it "supports multiple attachments" do
      patient = Patient.create(name: "Bob")
      Patient.attach_avatar(patient.id, filename: "a.jpg")
      Patient.attach_avatar(patient.id, filename: "b.jpg")

      expect(Patient.avatar_attachments(patient.id).size).to eq(2)
    end
  end

  describe "introspection" do
    it "exposes attachable_fields on the domain module" do
      mod = Object.const_get("AttachTestDomain")
      expect(mod.attachable_fields).to eq("Patient" => [:avatar])
    end
  end

  describe "DSL bare syntax" do
    it "supports avatar.attachable without capability. prefix" do
      hex = Hecks.hecksagon do
        aggregate "Patient" do
          avatar.attachable
        end
      end

      tags = hex.aggregate_capabilities["Patient"]
      expect(tags).to include({ attribute: "avatar", tag: :attachable })
    end
  end
end
