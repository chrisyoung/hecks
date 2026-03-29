require "spec_helper"
require "tmpdir"

RSpec.describe Hecks::Workshop do
  subject(:workshop) { described_class.new("Pizzas") }

  before { allow($stdout).to receive(:puts) }

  describe "#aggregate" do
    it "adds an aggregate" do
      workshop.aggregate "Pizza" do
        attribute :name, String
      end

      expect(workshop.aggregates).to eq(["Pizza"])
    end

    it "returns an AggregateHandle" do
      handle = workshop.aggregate("Pizza")
      expect(handle).to be_a(Hecks::Workshop::AggregateHandle)
    end

    it "returns the same handle each time" do
      a = workshop.aggregate("Pizza")
      b = workshop.aggregate("Pizza")
      expect(a).to equal(b)
    end

    it "accumulates across multiple calls" do
      workshop.aggregate "Pizza" do
        attribute :name, String
      end

      workshop.aggregate "Order" do
        attribute :quantity, Integer
      end

      expect(workshop.aggregates).to eq(["Pizza", "Order"])
    end

    it "merges into an existing aggregate" do
      workshop.aggregate "Pizza" do
        attribute :name, String
      end

      workshop.aggregate "Pizza" do
        command "CreatePizza" do
          attribute :name, String
        end
      end

      domain = workshop.to_domain
      pizza = domain.aggregates.first
      expect(pizza.attributes.map(&:name)).to include(:name)
      expect(pizza.commands.map(&:name)).to include("CreatePizza")
    end
  end

  describe "#to_domain" do
    it "returns a Domain" do
      workshop.aggregate "Pizza" do
        attribute :name, String
      end

      domain = workshop.to_domain
      expect(domain).to be_a(Hecks::DomainModel::Structure::Domain)
      expect(domain.name).to eq("Pizzas")
    end
  end

  describe "#validate" do
    it "returns true for a valid domain" do
      workshop.aggregate "Pizza" do
        attribute :name, String
        command "CreatePizza" do
          attribute :name, String
        end
      end

      expect(workshop.validate).to be true
    end

    it "returns false for an invalid domain" do
      workshop.aggregate "Order" do
        attribute :pizza_id, reference_to("Pizza")
        command "PlaceOrder" do
          attribute :pizza_id, reference_to("Pizza")
        end
      end

      expect(workshop.validate).to be false
    end
  end

  describe "#preview" do
    it "outputs generated code for an aggregate" do
      workshop.aggregate "Pizza" do
        attribute :name, String
      end

      expect { workshop.preview("Pizza") }.to output(/class Pizza/).to_stdout
    end
  end

  describe "#remove" do
    it "removes an aggregate" do
      workshop.aggregate "Pizza" do
        attribute :name, String
      end

      workshop.remove("Pizza")
      expect(workshop.aggregates).to be_empty
    end
  end

  describe "#describe" do
    it "prints the full domain summary" do
      workshop.aggregate "Pizza" do
        attribute :name, String
        command "CreatePizza" do
          attribute :name, String
        end
      end

      workshop.aggregate "Order" do
        attribute :pizza_id, reference_to("Pizza")
        attribute :quantity, Integer
        command "PlaceOrder" do
          attribute :pizza_id, reference_to("Pizza")
          attribute :quantity, Integer
        end
      end

      expect { workshop.describe }.to output(
        /Pizzas Domain.*Pizza.*Attributes:.*name.*Order.*Attributes:.*pizza_id.*reference_to/m
      ).to_stdout
    end
  end

  describe "#describe with queries, scopes, and subscribers" do
    it "includes queries in the output" do
      workshop.aggregate "Pizza" do
        attribute :name, String
        command "CreatePizza" do
          attribute :name, String
        end
        query "ByStyle" do |style|
          { style: style }
        end
      end

      expect { workshop.describe }.to output(/Queries: ByStyle/).to_stdout
    end

    it "includes scopes in the output" do
      workshop.aggregate "Pizza" do
        attribute :name, String
        attribute :status, String
        command "CreatePizza" do
          attribute :name, String
        end
        scope :active, status: "active"
        scope :large, size: "L"
      end

      expect { workshop.describe }.to output(/Scopes: active, large/).to_stdout
    end

    it "includes subscribers in the output" do
      workshop.aggregate "Pizza" do
        attribute :name, String
        command "CreatePizza" do
          attribute :name, String
        end
        on_event "CreatedPizza" do |event|
          # subscriber logic
        end
      end

      expect { workshop.describe }.to output(/Subscribers: on CreatedPizza/).to_stdout
    end
  end

  describe "#status" do
    it "is an alias for describe" do
      workshop.aggregate "Pizza" do
        attribute :name, String
      end

      expect { workshop.status }.to output(/Pizzas Domain/).to_stdout
    end
  end

  describe "#to_dsl" do
    it "generates valid DSL source" do
      workshop.aggregate "Pizza" do
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

      dsl = workshop.to_dsl
      expect(dsl).to include('Hecks.domain "Pizzas"')
      expect(dsl).to include('aggregate "Pizza"')
      expect(dsl).to include("attribute :name, String")
      expect(dsl).to include('list_of("Topping")')
      expect(dsl).to include('value_object "Topping"')
      expect(dsl).to include('command "CreatePizza"')
      expect(dsl).to include("validation :name")
    end

    it "produces source that can be re-evaluated" do
      workshop.aggregate "Pizza" do
        attribute :name, String
        command "CreatePizza" do
          attribute :name, String
        end
      end

      dsl = workshop.to_dsl
      domain = eval(dsl)
      expect(domain.aggregates.first.name).to eq("Pizza")
      expect(domain.aggregates.first.commands.first.name).to eq("CreatePizza")
    end
  end

  describe "#save" do
    it "writes domain.rb" do
      tmpdir = Dir.mktmpdir
      path = File.join(tmpdir, "domain.rb")

      workshop.aggregate "Pizza" do
        attribute :name, String
      end

      workshop.save(path)
      expect(File.exist?(path)).to be true
      expect(File.read(path)).to include('Hecks.domain "Pizzas"')

      FileUtils.rm_rf(tmpdir)
    end
  end

  describe "#build" do
    it "generates the domain gem" do
      tmpdir = Dir.mktmpdir

      workshop.aggregate "Pizza" do
        attribute :name, String
        command "CreatePizza" do
          attribute :name, String
        end
      end

      # Write version file so versioner works
      File.write(File.join(tmpdir, ".hecks_version"), "0.0.0")
      output = workshop.build(version: "1.0.0", output_dir: tmpdir)

      expect(Dir.exist?(output)).to be true
      expect(File.exist?(File.join(output, "lib/pizzas_domain.rb"))).to be true

      FileUtils.rm_rf(tmpdir)
    end
  end

  describe "#inspect" do
    it "shows a readable summary" do
      workshop.aggregate("Pizza") { attribute :name, String }
      expect(workshop.inspect).to eq('#<Hecks::Workshop "Pizzas" [sketch] (1 aggregates)>')
    end
  end

  describe "#add_verb" do
    it "adds a custom verb" do
      workshop.add_verb("Poop")
      domain = workshop.to_domain
      expect(domain.custom_verbs).to include("Poop")
    end

    it "does not add duplicates" do
      workshop.add_verb("Poop")
      workshop.add_verb("Poop")
      domain = workshop.to_domain
      expect(domain.custom_verbs.count("Poop")).to eq(1)
    end
  end

  describe "#active_hecks!" do
    it "enables active_hecks mode" do
      workshop.aggregate "Pizza" do
        attribute :name, String
        command "CreatePizza" do
          attribute :name, String
        end
      end

      workshop.active_hecks!
      expect(workshop.active_hecks?).to be true
    end
  end

  describe "play mode" do
    before do
      workshop.aggregate "Pizza" do
        attribute :name, String
        command "CreatePizza" do
          attribute :name, String
        end
      end
    end

    it "switches to play mode" do
      workshop.play!
      expect(workshop).to be_play
    end

    it "switches back to sketch mode" do
      workshop.play!
      workshop.sketch!
      expect(workshop).to be_sketch
    end

    it "lists available commands" do
      workshop.play!
      expect(workshop.commands).to include(/CreatePizza.*CreatedPizza/)
    end

    it "executes commands in play mode" do
      workshop.play!
      mod = Object.const_get("PizzasDomain")
      mod::Pizza.create(name: "Pepperoni")
      expect(workshop.events.size).to eq(1)
    end

    it "refuses play mode for invalid domains" do
      bad_workshop = described_class.new("Bad")
      bad_workshop.aggregate "Order" do
        attribute :pizza_id, reference_to("Pizza")
        command "PlaceOrder" do
          attribute :pizza_id, reference_to("Pizza")
        end
      end

      bad_workshop.play!
      expect(bad_workshop).to be_sketch
    end

    it "shows play in inspect" do
      workshop.play!
      expect(workshop.inspect).to include("[play]")
    end
  end

  describe "#browse" do
    before do
      pizza = workshop.aggregate("Pizza")
      pizza.attr :name, String
      pizza.command("CreatePizza") { attribute :name, String }
      workshop.aggregate("Order")
    end

    it "prints a tree of all aggregates" do
      expect { workshop.browse }.to output(/Pizzas Domain.*Pizza.*Order/m).to_stdout
    end

    it "prints a single aggregate" do
      expect { workshop.browse("Pizza") }.to output(/Pizza.*attributes.*commands/m).to_stdout
    end
  end

  describe "#promote" do
    let(:tmpdir) { Dir.mktmpdir("hecks-promote-") }

    before do
      workshop.aggregate "Pizza" do
        attribute :name, String
        command "CreatePizza" do
          attribute :name, String
        end
      end

      workshop.aggregate "Comment" do
        attribute :body, String
        command "CreateComment" do
          attribute :body, String
        end
      end

      Dir.chdir(tmpdir)
    end

    after do
      Dir.chdir("/")
      FileUtils.rm_rf(tmpdir)
    end

    it "creates a new domain file for the promoted aggregate" do
      workshop.promote("Comment")
      expect(File.exist?(File.join(tmpdir, "comment_domain.rb"))).to be true
      content = File.read(File.join(tmpdir, "comment_domain.rb"))
      expect(content).to include('Hecks.domain "Comment"')
      expect(content).to include('aggregate "Comment"')
      expect(content).to include('command "CreateComment"')
    end

    it "removes the promoted aggregate from the workshop" do
      workshop.promote("Comment")
      expect(workshop.aggregates).to eq(["Pizza"])
    end

    it "raises for unknown aggregate" do
      expect { workshop.promote("Nonexistent") }.to raise_error(RuntimeError, /No aggregate/)
    end
  end
end
