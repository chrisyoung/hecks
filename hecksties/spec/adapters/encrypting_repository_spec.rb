require "spec_helper"

RSpec.describe "EncryptingRepository" do
  let(:domain) do
    Hecks.domain "EncryptTest" do
      aggregate "Patient" do
        attribute :name, String
        attribute :ssn, String, encrypted: true
        attribute :email, String, encrypted: true

        command "RegisterPatient" do
          attribute :name, String
          attribute :ssn, String
          attribute :email, String
        end
      end
    end
  end

  before { @app = Hecks.load(domain) }

  describe "DSL" do
    it "marks attributes as encrypted" do
      agg = domain.aggregates.first
      encrypted = agg.attributes.select(&:encrypted?)
      expect(encrypted.map(&:name)).to eq([:ssn, :email])
    end

    it "non-encrypted attributes are not marked" do
      agg = domain.aggregates.first
      name_attr = agg.attributes.find { |a| a.name == :name }
      expect(name_attr.encrypted?).to be false
    end
  end

  describe "round-trip encrypt/decrypt" do
    it "transparently encrypts and decrypts on save/find" do
      patient = Patient.create(name: "Alice", ssn: "123-45-6789", email: "alice@example.com")

      found = Patient.find(patient.id)
      expect(found.name).to eq("Alice")
      expect(found.ssn).to eq("123-45-6789")
      expect(found.email).to eq("alice@example.com")
    end

    it "encrypts values in the inner repository" do
      patient = Patient.create(name: "Bob", ssn: "987-65-4321", email: "bob@example.com")

      # The class-level repo is the EncryptingRepository; reach into its inner repo
      encrypting_repo = Patient.instance_variable_get(:@__hecks_repo__)
      inner_repo = encrypting_repo.instance_variable_get(:@inner)
      raw = inner_repo.find(patient.id)

      # With TestEncryptor, values should be Base64-encoded
      expect(raw.ssn).not_to eq("987-65-4321")
      expect(raw.email).not_to eq("bob@example.com")
      # Unencrypted field should be unchanged
      expect(raw.name).to eq("Bob")
    end

    it "returns all records decrypted" do
      Patient.create(name: "Carol", ssn: "111-22-3333", email: "carol@example.com")
      Patient.create(name: "Dave", ssn: "444-55-6666", email: "dave@example.com")

      all = Patient.all
      expect(all.size).to eq(2)
      expect(all.map(&:ssn)).to contain_exactly("111-22-3333", "444-55-6666")
    end
  end

  describe "nil passthrough" do
    it "does not encrypt nil values" do
      patient = Patient.create(name: "Eve", ssn: nil, email: nil)

      found = Patient.find(patient.id)
      expect(found.ssn).to be_nil
      expect(found.email).to be_nil
    end
  end

  describe "delegation" do
    it "delegates delete to inner repository" do
      patient = Patient.create(name: "Frank", ssn: "000-00-0000", email: "frank@example.com")
      Patient.delete(patient.id)
      expect(Patient.find(patient.id)).to be_nil
    end

    it "delegates count to inner repository" do
      Patient.create(name: "Grace", ssn: "111-11-1111", email: "grace@example.com")
      expect(Patient.count).to eq(1)
    end
  end
end
