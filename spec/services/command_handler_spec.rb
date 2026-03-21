require "spec_helper"
require "tmpdir"

RSpec.describe "Command Handlers" do
  let(:handler_calls) { [] }

  let(:domain) do
    calls = handler_calls
    Hecks.domain "Pizzas" do
      aggregate "Pizza" do
        attribute :name, String

        command "CreatePizza" do
          attribute :name, String

          handler do |cmd|
            calls << { name: cmd.name }
            raise "Name cannot be blank" if cmd.name.nil? || cmd.name.empty?
          end
        end
      end

      aggregate "Order" do
        attribute :quantity, Integer
        attribute :status, String

        command "PlaceOrder" do
          attribute :quantity, Integer

          handler do |cmd|
            calls << { quantity: cmd.quantity }
            raise "Quantity must be positive" unless cmd.quantity.is_a?(Integer) && cmd.quantity > 0
          end
        end
      end
    end
  end

  let!(:app) do
    tmpdir = Dir.mktmpdir("hecks_handler_test")
    gen = Hecks::Generators::DomainGemGenerator.new(domain, version: "0.0.0", output_dir: tmpdir)
    gem_path = gen.generate
    lib_path = File.join(gem_path, "lib")
    $LOAD_PATH.unshift(lib_path) unless $LOAD_PATH.include?(lib_path)
    entry = File.join(lib_path, "pizzas_domain.rb")
    load entry
    Dir[File.join(lib_path, "**/*.rb")].sort.each { |f| load f }
    Hecks::Services::Application.new(domain)
  end

  let(:pizza_class) { PizzasDomain::Pizza }
  let(:order_class) { PizzasDomain::Order }

  describe "handler defined in DSL" do
    it "stores the handler on the domain model command" do
      pizza_agg = domain.aggregates.find { |a| a.name == "Pizza" }
      cmd = pizza_agg.commands.find { |c| c.name == "CreatePizza" }
      expect(cmd.handler).to be_a(Proc)
    end
  end

  describe "handler receives command data" do
    it "can read attributes from the command object" do
      pizza_class.create(name: "Margherita")
      expect(handler_calls).to include(name: "Margherita")
    end
  end

  describe "handler that passes" do
    it "allows normal flow: event fires, aggregate saved" do
      pizza_class.create(name: "Pepperoni")
      expect(app.events.size).to eq(1)
      expect(app["Pizza"].all.size).to eq(1)
      expect(app["Pizza"].all.first.name).to eq("Pepperoni")
    end
  end

  describe "handler that raises" do
    it "prevents event and save for create commands" do
      expect { pizza_class.create(name: "") }.to raise_error("Name cannot be blank")
      expect(app.events.size).to eq(0)
      expect(app["Pizza"].all.size).to eq(0)
    end

    it "prevents event and save for non-create commands" do
      expect { order_class.place(quantity: -1) }.to raise_error("Quantity must be positive")
      expect(app.events.size).to eq(0)
      expect(app["Order"].all.size).to eq(0)
    end
  end

  describe "command without handler (backward compat)" do
    let(:plain_domain) do
      Hecks.domain "Pizzas" do
        aggregate "Pizza" do
          attribute :name, String
          command "CreatePizza" do
            attribute :name, String
          end
        end
      end
    end

    it "works normally without a handler" do
      tmpdir = Dir.mktmpdir("hecks_no_handler_test")
      gen = Hecks::Generators::DomainGemGenerator.new(plain_domain, version: "0.0.0", output_dir: tmpdir)
      gem_path = gen.generate
      lib_path = File.join(gem_path, "lib")
      $LOAD_PATH.unshift(lib_path) unless $LOAD_PATH.include?(lib_path)
      Dir[File.join(lib_path, "**/*.rb")].sort.each { |f| load f }

      plain_app = Hecks::Services::Application.new(plain_domain)
      PizzasDomain::Pizza.create(name: "Cheese")

      expect(plain_app.events.size).to eq(1)
      expect(plain_app["Pizza"].all.size).to eq(1)
    end
  end

  describe "handler in play mode" do
    it "calls the handler before firing events" do
      session = Hecks::Session.new("Pizzas")
      calls = handler_calls

      session.aggregate "Pizza" do
        attribute :name, String
        command "CreatePizza" do
          attribute :name, String
          handler do |cmd|
            calls << { play_name: cmd.name }
            raise "No blank names" if cmd.name.nil? || cmd.name.empty?
          end
        end
      end

      allow($stdout).to receive(:puts)
      session.play!

      expect { session.execute("CreatePizza", name: "") }.to raise_error("No blank names")
      expect(session.events.size).to eq(0)

      session.execute("CreatePizza", name: "Good")
      expect(session.events.size).to eq(1)
      expect(handler_calls).to include(play_name: "Good")
    end
  end
end
