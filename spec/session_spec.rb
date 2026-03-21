require "spec_helper"
require "tmpdir"

RSpec.describe Hecks::Session do
  subject(:session) { described_class.new("Pizzas") }

  before { allow($stdout).to receive(:puts) }

  describe "#aggregate" do
    it "adds an aggregate" do
      session.aggregate "Pizza" do
        attribute :name, String
      end

      expect(session.aggregates).to eq(["Pizza"])
    end

    it "returns an AggregateHandle" do
      handle = session.aggregate("Pizza")
      expect(handle).to be_a(Hecks::AggregateHandle)
    end

    it "returns the same handle each time" do
      a = session.aggregate("Pizza")
      b = session.aggregate("Pizza")
      expect(a).to equal(b)
    end

    it "accumulates across multiple calls" do
      session.aggregate "Pizza" do
        attribute :name, String
      end

      session.aggregate "Order" do
        attribute :quantity, Integer
      end

      expect(session.aggregates).to eq(["Pizza", "Order"])
    end

    it "merges into an existing aggregate" do
      session.aggregate "Pizza" do
        attribute :name, String
      end

      session.aggregate "Pizza" do
        command "CreatePizza" do
          attribute :name, String
        end
      end

      domain = session.to_domain
      pizza = domain.aggregates.first
      expect(pizza.attributes.map(&:name)).to include(:name)
      expect(pizza.commands.map(&:name)).to include("CreatePizza")
    end
  end

  describe "#to_domain" do
    it "returns a Domain" do
      session.aggregate "Pizza" do
        attribute :name, String
      end

      domain = session.to_domain
      expect(domain).to be_a(Hecks::DomainModel::Domain)
      expect(domain.name).to eq("Pizzas")
    end
  end

  describe "#validate" do
    it "returns true for a valid domain" do
      session.aggregate "Pizza" do
        attribute :name, String
        command "CreatePizza" do
          attribute :name, String
        end
      end

      expect(session.validate).to be true
    end

    it "returns false for an invalid domain" do
      session.aggregate "Order" do
        attribute :pizza_id, reference_to("Pizza")
        command "PlaceOrder" do
          attribute :pizza_id, reference_to("Pizza")
        end
      end

      expect(session.validate).to be false
    end
  end

  describe "#preview" do
    it "outputs generated code for an aggregate" do
      session.aggregate "Pizza" do
        attribute :name, String
      end

      expect { session.preview("Pizza") }.to output(/class Pizza/).to_stdout
    end
  end

  describe "#remove" do
    it "removes an aggregate" do
      session.aggregate "Pizza" do
        attribute :name, String
      end

      session.remove("Pizza")
      expect(session.aggregates).to be_empty
    end
  end

  describe "#describe" do
    it "prints the full domain summary" do
      session.aggregate "Pizza" do
        attribute :name, String
        command "CreatePizza" do
          attribute :name, String
        end
      end

      session.aggregate "Order" do
        attribute :pizza_id, reference_to("Pizza")
        attribute :quantity, Integer
        command "PlaceOrder" do
          attribute :pizza_id, reference_to("Pizza")
          attribute :quantity, Integer
        end
      end

      expect { session.describe }.to output(
        /Pizzas Domain.*Pizza.*Attributes:.*name.*Order.*Attributes:.*pizza_id.*reference_to/m
      ).to_stdout
    end
  end

  describe "#status" do
    it "is an alias for describe" do
      session.aggregate "Pizza" do
        attribute :name, String
      end

      expect { session.status }.to output(/Pizzas Domain/).to_stdout
    end
  end

  describe "#to_dsl" do
    it "generates valid DSL source" do
      session.aggregate "Pizza" do
        attribute :name, String
        attribute :toppings, list_of("Topping")

        value_object "Topping" do
          attribute :name, String
        end

        validation :name, presence: true

        command "CreatePizza" do
          attribute :name, String
        end
      end

      dsl = session.to_dsl
      expect(dsl).to include('Hecks.domain "Pizzas"')
      expect(dsl).to include('aggregate "Pizza"')
      expect(dsl).to include("attribute :name, String")
      expect(dsl).to include('list_of("Topping")')
      expect(dsl).to include('value_object "Topping"')
      expect(dsl).to include('command "CreatePizza"')
      expect(dsl).to include("validation :name")
    end

    it "produces source that can be re-evaluated" do
      session.aggregate "Pizza" do
        attribute :name, String
        command "CreatePizza" do
          attribute :name, String
        end
      end

      dsl = session.to_dsl
      domain = eval(dsl)
      expect(domain.aggregates.first.name).to eq("Pizza")
      expect(domain.aggregates.first.commands.first.name).to eq("CreatePizza")
    end
  end

  describe "#save" do
    it "writes domain.rb" do
      tmpdir = Dir.mktmpdir
      path = File.join(tmpdir, "domain.rb")

      session.aggregate "Pizza" do
        attribute :name, String
      end

      session.save(path)
      expect(File.exist?(path)).to be true
      expect(File.read(path)).to include('Hecks.domain "Pizzas"')

      FileUtils.rm_rf(tmpdir)
    end
  end

  describe "#build" do
    it "generates the domain gem" do
      tmpdir = Dir.mktmpdir

      session.aggregate "Pizza" do
        attribute :name, String
        command "CreatePizza" do
          attribute :name, String
        end
      end

      # Write version file so versioner works
      File.write(File.join(tmpdir, ".hecks_version"), "0.0.0")
      output = session.build(version: "1.0.0", output_dir: tmpdir)

      expect(Dir.exist?(output)).to be true
      expect(File.exist?(File.join(output, "lib/pizzas_domain.rb"))).to be true

      FileUtils.rm_rf(tmpdir)
    end
  end

  describe "#inspect" do
    it "shows a readable summary" do
      session.aggregate("Pizza") { attribute :name, String }
      expect(session.inspect).to eq('#<Hecks::Session "Pizzas" [build] (1 aggregates)>')
    end
  end

  describe "play mode" do
    before do
      session.aggregate "Pizza" do
        attribute :name, String
        command "CreatePizza" do
          attribute :name, String
        end
      end
    end

    it "switches to play mode" do
      session.play!
      expect(session).to be_play
    end

    it "switches back to build mode" do
      session.play!
      session.build!
      expect(session).to be_build
    end

    it "lists available commands" do
      session.play!
      expect(session.commands).to include(/CreatePizza.*CreatedPizza/)
    end

    it "executes commands in play mode" do
      session.play!
      event = session.execute("CreatePizza", name: "Pepperoni")
      expect(session.events.size).to eq(1)
    end

    it "raises when calling play methods in build mode" do
      expect { session.execute("CreatePizza", name: "X") }.to raise_error(/Not in play mode/)
    end

    it "refuses play mode for invalid domains" do
      bad_session = described_class.new("Bad")
      bad_session.aggregate "Order" do
        attribute :pizza_id, reference_to("Pizza")
        command "PlaceOrder" do
          attribute :pizza_id, reference_to("Pizza")
        end
      end

      bad_session.play!
      expect(bad_session).to be_build
    end

    it "shows play in inspect" do
      session.play!
      expect(session.inspect).to include("[play]")
    end
  end
end
