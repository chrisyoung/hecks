require "spec_helper"
require "hecks/extensions/crud"

RSpec.describe "CRUD extension" do
  let(:domain_with_create) do
    Hecks.domain "Animals" do
      aggregate "Cat" do
        attribute :name, String
        attribute :color, String

        command "CreateCat" do
          attribute :name, String
          attribute :color, String
        end
      end
    end
  end

  let(:domain_with_all) do
    Hecks.domain "Widgets" do
      aggregate "Widget" do
        attribute :label, String

        command "CreateWidget" do
          attribute :label, String
        end

        command "UpdateWidget" do
          attribute :label, String
          reference_to "Widget"
        end

        command "DeleteWidget" do
          reference_to "Widget"
        end
      end
    end
  end

  describe "without :crud extension" do
    it "does not auto-generate Update or Delete commands" do
      app = Hecks.load(domain_with_create)

      cmd_names = domain_with_create.aggregates.first.commands.map(&:name)
      expect(cmd_names).to eq(["CreateCat"])
    end
  end

  describe "with :crud extension (generate_all)" do
    it "generates missing Update and Delete commands" do
      app = Hecks.load(domain_with_create)
      Hecks::Crud::CommandGenerator.generate_all(
        AnimalsDomain, domain_with_create, app
      )

      cmd_names = domain_with_create.aggregates.first.commands.map(&:name)
      expect(cmd_names).to include("CreateCat", "UpdateCat", "DeleteCat")
    end

    it "generates matching events" do
      app = Hecks.load(domain_with_create)
      Hecks::Crud::CommandGenerator.generate_all(
        AnimalsDomain, domain_with_create, app
      )

      event_names = domain_with_create.aggregates.first.events.map(&:name)
      expect(event_names).to include("UpdatedCat", "DeletedCat")
    end

    it "wires shortcut methods on the aggregate class" do
      app = Hecks.load(domain_with_create)
      Hecks::Crud::CommandGenerator.generate_all(
        AnimalsDomain, domain_with_create, app
      )

      expect(Cat).to respond_to(:create)
      expect(Cat).to respond_to(:update)
      expect(Cat).to respond_to(:delete)
    end

    it "create command still works" do
      app = Hecks.load(domain_with_create)
      Hecks::Crud::CommandGenerator.generate_all(
        AnimalsDomain, domain_with_create, app
      )

      cat = Cat.create(name: "Whiskers", color: "orange")
      expect(cat.name).to eq("Whiskers")
      expect(Cat.find(cat.id)).not_to be_nil
    end

    it "update command merges changed attributes" do
      app = Hecks.load(domain_with_create)
      Hecks::Crud::CommandGenerator.generate_all(
        AnimalsDomain, domain_with_create, app
      )

      cat = Cat.create(name: "Whiskers", color: "orange")
      Cat.update(cat: cat.id, name: "Mittens")
      found = Cat.find(cat.id)
      expect(found.name).to eq("Mittens")
      expect(found.color).to eq("orange")
    end

    it "delete command removes the aggregate" do
      app = Hecks.load(domain_with_create)
      Hecks::Crud::CommandGenerator.generate_all(
        AnimalsDomain, domain_with_create, app
      )

      cat = Cat.create(name: "Whiskers", color: "orange")
      Cat.delete(cat: cat.id)
      expect(Cat.find(cat.id)).to be_nil
    end
  end

  describe "enrich path (pre-load for bare aggregates)" do
    it "adds CRUD commands to bare aggregates before load" do
      bare = Hecks.domain "Pets" do
        aggregate "Dog" do
          attribute :breed, String
        end
      end

      Hecks::Crud::CommandGenerator.enrich(bare)
      Hecks.load(bare)

      cmd_names = bare.aggregates.first.commands.map(&:name)
      expect(cmd_names).to include("CreateDog", "UpdateDog", "DeleteDog")
      expect(Dog).to respond_to(:create)
    end
  end

  describe "idempotent when commands already exist" do
    it "skips generation for existing commands" do
      app = Hecks.load(domain_with_all)
      Hecks::Crud::CommandGenerator.generate_all(
        WidgetsDomain, domain_with_all, app
      )

      cmd_names = domain_with_all.aggregates.first.commands.map(&:name)
      expect(cmd_names.count { |n| n == "CreateWidget" }).to eq(1)
      expect(cmd_names.count { |n| n == "UpdateWidget" }).to eq(1)
      expect(cmd_names.count { |n| n == "DeleteWidget" }).to eq(1)
    end
  end

  describe "events fire on the event bus" do
    it "emits UpdatedCat event" do
      app = Hecks.load(domain_with_create)
      Hecks::Crud::CommandGenerator.generate_all(
        AnimalsDomain, domain_with_create, app
      )

      events = []
      app.on("UpdatedCat") { |e| events << e }
      cat = Cat.create(name: "Luna", color: "black")
      Cat.update(cat: cat.id, name: "Shadow")
      expect(events.size).to eq(1)
      expect(events.first.name).to eq("Shadow")
    end

    it "emits DeletedCat event" do
      app = Hecks.load(domain_with_create)
      Hecks::Crud::CommandGenerator.generate_all(
        AnimalsDomain, domain_with_create, app
      )

      events = []
      app.on("DeletedCat") { |e| events << e }
      cat = Cat.create(name: "Luna", color: "black")
      Cat.delete(cat: cat.id)
      expect(events.size).to eq(1)
    end
  end
end
