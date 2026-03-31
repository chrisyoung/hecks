require "spec_helper"
require "active_hecks"

RSpec.describe "ActiveHecks::PersistenceWrapper" do
  before(:all) do
    domain = Hecks.domain "Bakery" do
      aggregate "Bread" do
        attribute :name, String
        validation :name, presence: true
        command "CreateBread" do
          attribute :name, String
        end
      end
    end

    @app = Hecks.load(domain)
    ActiveHecks.activate(BakeryDomain)
  end

  describe "#save" do
    it "returns false when invalid" do
      expect(BakeryDomain::Bread.new(name: "").save).to eq(false)
    end

    it "returns the object when valid" do
      bread = BakeryDomain::Bread.new(name: "Sourdough")
      expect(bread.save).to eq(bread)
    end

    it "does not persist invalid objects" do
      count_before = BakeryDomain::Bread.count
      BakeryDomain::Bread.new(name: "").save
      expect(BakeryDomain::Bread.count).to eq(count_before)
    end

    it "persists valid objects" do
      count_before = BakeryDomain::Bread.count
      BakeryDomain::Bread.new(name: "Rye").save
      expect(BakeryDomain::Bread.count).to eq(count_before + 1)
    end
  end

  describe "#save!" do
    it "raises ActiveModel::ValidationError when invalid" do
      expect { BakeryDomain::Bread.new(name: "").save! }.to raise_error(ActiveModel::ValidationError)
    end

    it "saves and returns the object when valid" do
      bread = BakeryDomain::Bread.new(name: "Pumpernickel")
      expect(bread.save!).to eq(bread)
    end
  end

  describe "#destroy" do
    it "marks the object as destroyed" do
      bread = BakeryDomain::Bread.new(name: "Baguette")
      bread.save
      bread.destroy
      expect(bread).to be_destroyed
    end
  end

  describe "save callbacks" do
    it "runs before_save" do
      called = false
      BakeryDomain::Bread.before_save { called = true }
      BakeryDomain::Bread.new(name: "Ciabatta").save
      expect(called).to eq(true)
    end

    it "does not run save callbacks when invalid" do
      called = false
      BakeryDomain::Bread.before_save { called = true }
      BakeryDomain::Bread.new(name: "").save
      expect(called).to eq(false)
    end
  end
end
