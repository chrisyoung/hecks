require "spec_helper"

RSpec.describe "Play mode" do
  let(:session) { Hecks::Session.new("Scratch") }

  before do
    allow($stdout).to receive(:puts)

    pizza = session.aggregate("Pizza")
    pizza.add_attribute :name, String
    pizza.add_attribute :style, String
    pizza.add_command("CreatePizza") do
      attribute :name, String
      attribute :style, String
    end
    pizza.add_command("RenamePizza") { attribute :name, String }

    cat = session.aggregate("Cat")
    cat.add_attribute :name, String
    cat.add_command("Meow") { attribute :name, String }
  end

  describe "entering play mode" do
    it "compiles and enters play mode" do
      session.play!
      expect(session.play?).to be true
    end

    it "makes aggregate classes available" do
      session.play!
      mod = Object.const_get("ScratchDomain")
      expect(mod.const_defined?(:Pizza)).to be true
      expect(mod.const_defined?(:Cat)).to be true
    end

    it "can create aggregate instances" do
      session.play!
      mod = Object.const_get("ScratchDomain")
      pizza = mod::Pizza.new(name: "Margherita")
      expect(pizza.name).to eq("Margherita")
    end
  end

  describe "execute" do
    before { session.play! }

    it "executes a command by name" do
      event = session.execute("CreatePizza", name: "Pepperoni", style: "NY")
      expect(event).to be_a(Object)
      expect(event.name).to eq("Pepperoni")
    end

    it "collects events" do
      session.execute("CreatePizza", name: "Margherita", style: "Neapolitan")
      session.execute("Meow", name: "Henry")
      expect(session.events.size).to eq(2)
    end

    it "raises for unknown command" do
      expect { session.execute("FlyToMoon") }.to raise_error(/Unknown command/)
    end
  end

  describe "command shortcut class methods" do
    before { session.play! }

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
      # CreatePizza -> create (not create_pizza)
      expect(mod::Pizza).to respond_to(:create)
      # RenamePizza -> rename
      expect(mod::Pizza).to respond_to(:rename)
    end
  end

  describe "command shortcut instance methods" do
    before { session.play! }

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
    before { session.play! }

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
    before { session.play! }

    it "events_of filters by type" do
      session.execute("CreatePizza", name: "A", style: "NY")
      session.execute("Meow", name: "Henry")
      session.execute("CreatePizza", name: "B", style: "Chicago")

      created = session.events_of("CreatedPizza")
      expect(created.size).to eq(2)
    end

    it "history prints timeline" do
      session.execute("CreatePizza", name: "Margherita", style: "NY")
      expect { session.history }.to output(/1\. CreatedPizza/).to_stdout
    end

    it "reset clears events" do
      session.execute("CreatePizza", name: "Test", style: "NY")
      session.reset!
      expect(session.events).to be_empty
    end
  end

  describe "define! / play! toggling" do
    it "can switch back to define mode" do
      session.play!
      session.define!
      expect(session.play?).to be false
    end

    it "can re-enter play mode after changes" do
      cat = session.aggregate("Cat")
      cat.add_command("Purr") { attribute :name, String }
      session.play!

      mod = Object.const_get("ScratchDomain")
      cat_instance = mod::Cat.new(name: "Henry")
      event = cat_instance.purr
      expect(event.name).to eq("Henry")
    end
  end
end
