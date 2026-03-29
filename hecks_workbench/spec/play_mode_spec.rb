require "spec_helper"

RSpec.describe "Play mode" do
  let(:workbench) { Hecks::Workbench.new("Scratch") }

  before do
    allow($stdout).to receive(:puts)

    pizza = workbench.aggregate("Pizza")
    pizza.attr :name, String
    pizza.attr :style, String
    pizza.command("CreatePizza") do
      attribute :name, String
      attribute :style, String
    end
    pizza.command("RenamePizza") { attribute :name, String }

    cat = workbench.aggregate("Cat")
    cat.attr :name, String
    cat.command("Meow") { attribute :name, String }
  end

  describe "entering play mode" do
    it "compiles and enters play mode" do
      workbench.play!
      expect(workbench.play?).to be true
    end

    it "makes aggregate classes available" do
      workbench.play!
      mod = Object.const_get("ScratchDomain")
      expect(mod.const_defined?(:Pizza)).to be true
      expect(mod.const_defined?(:Cat)).to be true
    end

    it "can create aggregate instances" do
      workbench.play!
      mod = Object.const_get("ScratchDomain")
      pizza = mod::Pizza.new(name: "Margherita")
      expect(pizza.name).to eq("Margherita")
    end
  end

  describe "execute" do
    before { workbench.play! }

    it "executes a command by name" do
      mod = Object.const_get("ScratchDomain")
      pizza = mod::Pizza.create(name: "Pepperoni", style: "NY")
      expect(pizza).to be_a(Object)
      expect(pizza.name).to eq("Pepperoni")
    end

    it "collects events" do
      mod = Object.const_get("ScratchDomain")
      mod::Pizza.create(name: "Margherita", style: "Neapolitan")
      mod::Cat.meow(name: "Henry")
      expect(workbench.events.size).to eq(2)
    end
  end

  describe "command shortcut class methods" do
    before { workbench.play! }

    it "defines class methods on aggregates" do
      mod = Object.const_get("ScratchDomain")
      expect(mod::Pizza).to respond_to(:create)
      expect(mod::Cat).to respond_to(:meow)
    end

    it "executes via class method" do
      mod = Object.const_get("ScratchDomain")
      event = mod::Pizza.create(name: "Pepperoni", style: "NY")
      expect(event.name).to eq("Pepperoni")
    end

    it "strips aggregate suffix from method name" do
      mod = Object.const_get("ScratchDomain")
      # CreatePizza -> create (not create)
      expect(mod::Pizza).to respond_to(:create)
      # RenamePizza -> rename
      expect(mod::Pizza).to respond_to(:rename)
    end
  end

  describe "command shortcut instance methods" do
    before { workbench.play! }

    it "defines instance methods on aggregates" do
      mod = Object.const_get("ScratchDomain")
      cat = mod::Cat.new(name: "Henry")
      expect(cat).to respond_to(:meow)
    end

    it "auto-fills from instance attributes" do
      mod = Object.const_get("ScratchDomain")
      cat = mod::Cat.new(name: "Henry")
      event = cat.meow
      expect(event.name).to eq("Henry")
    end

    it "accepts keyword overrides" do
      mod = Object.const_get("ScratchDomain")
      cat = mod::Cat.new(name: "Henry")
      event = cat.meow(name: "Whiskers")
      expect(event.name).to eq("Whiskers")
    end

    it "works with multiple attributes" do
      mod = Object.const_get("ScratchDomain")
      pizza = mod::Pizza.new(name: "Margherita", style: "Neapolitan")
      event = pizza.create
      expect(event.name).to eq("Margherita")
    end

    it "allows partial overrides" do
      mod = Object.const_get("ScratchDomain")
      pizza = mod::Pizza.new(name: "Margherita", style: "Neapolitan")
      event = pizza.create(name: "Pepperoni")
      expect(event.name).to eq("Pepperoni")
    end
  end

  describe "reset!" do
    before { workbench.play! }

    it "restores attributes to constructor values" do
      mod = Object.const_get("ScratchDomain")
      cat = mod::Cat.new(name: "Henry")
      cat.name = "Whiskers"
      expect(cat.name).to eq("Whiskers")

      cat.reset!
      expect(cat.name).to eq("Henry")
    end

    it "preserves identity" do
      mod = Object.const_get("ScratchDomain")
      cat = mod::Cat.new(name: "Henry")
      id = cat.id
      cat.name = "Whiskers"
      cat.reset!
      expect(cat.id).to eq(id)
    end

    it "returns self for chaining" do
      mod = Object.const_get("ScratchDomain")
      cat = mod::Cat.new(name: "Henry")
      cat.name = "Whiskers"
      expect(cat.reset!).to equal(cat)
    end
  end

  describe "events and history" do
    before { workbench.play! }

    it "events_of filters by type" do
      mod = Object.const_get("ScratchDomain")
      mod::Pizza.create(name: "A", style: "NY")
      mod::Cat.meow(name: "Henry")
      mod::Pizza.create(name: "B", style: "Chicago")

      created = workbench.events_of("CreatedPizza")
      expect(created.size).to eq(2)
    end

    it "history prints timeline" do
      mod = Object.const_get("ScratchDomain")
      mod::Pizza.create(name: "Margherita", style: "NY")
      expect { workbench.history }.to output(/1\. CreatedPizza/).to_stdout
    end

    it "reset clears events" do
      mod = Object.const_get("ScratchDomain")
      mod::Pizza.create(name: "Test", style: "NY")
      workbench.reset!
      expect(workbench.events).to be_empty
    end
  end

  describe "persistence" do
    before { workbench.play! }

    it "persists aggregates after execute" do
      mod = Object.const_get("ScratchDomain")
      result = mod::Pizza.create(name: "Margherita", style: "NY")
      found = mod::Pizza.find(result.id)
      expect(found.name).to eq("Margherita")
    end

    it "supports all" do
      mod = Object.const_get("ScratchDomain")
      mod::Pizza.create(name: "A", style: "NY")
      mod::Pizza.create(name: "B", style: "Chicago")
      expect(mod::Pizza.all.size).to eq(2)
    end

    it "supports count" do
      mod = Object.const_get("ScratchDomain")
      mod::Cat.meow(name: "Henry")
      mod::Cat.meow(name: "Whiskers")
      expect(mod::Cat.count).to eq(2)
    end

    it "persists via class method shortcuts" do
      mod = Object.const_get("ScratchDomain")
      pizza = mod::Pizza.create(name: "Pepperoni", style: "NY")
      expect(mod::Pizza.find(pizza.id).name).to eq("Pepperoni")
    end

    it "reset clears repository data" do
      mod = Object.const_get("ScratchDomain")
      mod::Pizza.create(name: "Test", style: "NY")
      expect(mod::Pizza.count).to eq(1)
      workbench.reset!
      expect(mod::Pizza.count).to eq(0)
    end
  end

  describe "sketch! / play! toggling" do
    it "can switch back to sketch mode" do
      workbench.play!
      workbench.sketch!
      expect(workbench.play?).to be false
    end

    it "can re-enter play mode after changes" do
      cat = workbench.aggregate("Cat")
      cat.command("Purr") { attribute :name, String }
      workbench.play!

      mod = Object.const_get("ScratchDomain")
      cat_instance = mod::Cat.new(name: "Henry")
      event = cat_instance.purr
      expect(event.name).to eq("Henry")
    end
  end

  describe "live extend" do
    before { workbench.play! }

    it "applies logging extension to running runtime" do
      workbench.extend(:logging)
      mod = Object.const_get("ScratchDomain")
      expect { mod::Pizza.create(name: "Test", style: "NY") }.to output(/CreatePizza/).to_stdout
    end

    it "raises for unknown extension" do
      expect { workbench.extend(:nonexistent) }.to raise_error(RuntimeError, /Unknown extension/)
    end

    it "requires play mode" do
      workbench.sketch!
      expect { workbench.extend(:logging) }.to raise_error(RuntimeError, /Not in play mode/)
    end
  end
end
