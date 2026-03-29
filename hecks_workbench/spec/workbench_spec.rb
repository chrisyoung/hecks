require "spec_helper"
require "tmpdir"

RSpec.describe Hecks::Workbench do
  subject(:workbench) { described_class.new("Pizzas") }

  before { allow($stdout).to receive(:puts) }

  describe "#aggregate" do
    it "adds an aggregate" do
      workbench.aggregate "Pizza" do
        attribute :name, String
      end

      expect(workbench.aggregates).to eq(["Pizza"])
    end

    it "returns an AggregateHandle" do
      handle = workbench.aggregate("Pizza")
      expect(handle).to be_a(Hecks::Workbench::AggregateHandle)
    end

    it "returns the same handle each time" do
      a = workbench.aggregate("Pizza")
      b = workbench.aggregate("Pizza")
      expect(a).to equal(b)
    end

    it "accumulates across multiple calls" do
      workbench.aggregate "Pizza" do
        attribute :name, String
      end

      workbench.aggregate "Order" do
        attribute :quantity, Integer
      end

      expect(workbench.aggregates).to eq(["Pizza", "Order"])
    end

    it "merges into an existing aggregate" do
      workbench.aggregate "Pizza" do
        attribute :name, String
      end

      workbench.aggregate "Pizza" do
        command "CreatePizza" do
          attribute :name, String
        end
      end

      domain = workbench.to_domain
      pizza = domain.aggregates.first
      expect(pizza.attributes.map(&:name)).to include(:name)
      expect(pizza.commands.map(&:name)).to include("CreatePizza")
    end
  end

  describe "#to_domain" do
    it "returns a Domain" do
      workbench.aggregate "Pizza" do
        attribute :name, String
      end

      domain = workbench.to_domain
      expect(domain).to be_a(Hecks::DomainModel::Structure::Domain)
      expect(domain.name).to eq("Pizzas")
    end
  end

  describe "#validate" do
    it "returns true for a valid domain" do
      workbench.aggregate "Pizza" do
        attribute :name, String
        command "CreatePizza" do
          attribute :name, String
        end
      end

      expect(workbench.validate).to be true
    end

    it "returns false for an invalid domain" do
      workbench.aggregate "Order" do
        attribute :pizza_id, reference_to("Pizza")
        command "PlaceOrder" do
          attribute :pizza_id, reference_to("Pizza")
        end
      end

      expect(workbench.validate).to be false
    end
  end

  describe "#preview" do
    it "outputs generated code for an aggregate" do
      workbench.aggregate "Pizza" do
        attribute :name, String
      end

      expect { workbench.preview("Pizza") }.to output(/class Pizza/).to_stdout
    end
  end

  describe "#remove" do
    it "removes an aggregate" do
      workbench.aggregate "Pizza" do
        attribute :name, String
      end

      workbench.remove("Pizza")
      expect(workbench.aggregates).to be_empty
    end
  end

  describe "#describe" do
    it "prints the full domain summary" do
      workbench.aggregate "Pizza" do
        attribute :name, String
        command "CreatePizza" do
          attribute :name, String
        end
      end

      workbench.aggregate "Order" do
        attribute :pizza_id, reference_to("Pizza")
        attribute :quantity, Integer
        command "PlaceOrder" do
          attribute :pizza_id, reference_to("Pizza")
          attribute :quantity, Integer
        end
      end

      expect { workbench.describe }.to output(
        /Pizzas Domain.*Pizza.*Attributes:.*name.*Order.*Attributes:.*pizza_id.*reference_to/m
      ).to_stdout
    end
  end

  describe "#describe with queries, scopes, and subscribers" do
    it "includes queries in the output" do
      workbench.aggregate "Pizza" do
        attribute :name, String
        command "CreatePizza" do
          attribute :name, String
        end
        query "ByStyle" do |style|
          { style: style }
        end
      end

      expect { workbench.describe }.to output(/Queries: ByStyle/).to_stdout
    end

    it "includes scopes in the output" do
      workbench.aggregate "Pizza" do
        attribute :name, String
        attribute :status, String
        command "CreatePizza" do
          attribute :name, String
        end
        scope :active, status: "active"
        scope :large, size: "L"
      end

      expect { workbench.describe }.to output(/Scopes: active, large/).to_stdout
    end

    it "includes subscribers in the output" do
      workbench.aggregate "Pizza" do
        attribute :name, String
        command "CreatePizza" do
          attribute :name, String
        end
        on_event "CreatedPizza" do |event|
          # subscriber logic
        end
      end

      expect { workbench.describe }.to output(/Subscribers: on CreatedPizza/).to_stdout
    end
  end

  describe "#status" do
    it "is an alias for describe" do
      workbench.aggregate "Pizza" do
        attribute :name, String
      end

      expect { workbench.status }.to output(/Pizzas Domain/).to_stdout
    end
  end

  describe "#to_dsl" do
    it "generates valid DSL source" do
      workbench.aggregate "Pizza" do
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

      dsl = workbench.to_dsl
      expect(dsl).to include('Hecks.domain "Pizzas"')
      expect(dsl).to include('aggregate "Pizza"')
      expect(dsl).to include("attribute :name, String")
      expect(dsl).to include('list_of("Topping")')
      expect(dsl).to include('value_object "Topping"')
      expect(dsl).to include('command "CreatePizza"')
      expect(dsl).to include("validation :name")
    end

    it "produces source that can be re-evaluated" do
      workbench.aggregate "Pizza" do
        attribute :name, String
        command "CreatePizza" do
          attribute :name, String
        end
      end

      dsl = workbench.to_dsl
      domain = eval(dsl)
      expect(domain.aggregates.first.name).to eq("Pizza")
      expect(domain.aggregates.first.commands.first.name).to eq("CreatePizza")
    end
  end

  describe "#save" do
    it "writes domain.rb" do
      tmpdir = Dir.mktmpdir
      path = File.join(tmpdir, "domain.rb")

      workbench.aggregate "Pizza" do
        attribute :name, String
      end

      workbench.save(path)
      expect(File.exist?(path)).to be true
      expect(File.read(path)).to include('Hecks.domain "Pizzas"')

      FileUtils.rm_rf(tmpdir)
    end
  end

  describe "#build" do
    it "generates the domain gem" do
      tmpdir = Dir.mktmpdir

      workbench.aggregate "Pizza" do
        attribute :name, String
        command "CreatePizza" do
          attribute :name, String
        end
      end

      # Write version file so versioner works
      File.write(File.join(tmpdir, ".hecks_version"), "0.0.0")
      output = workbench.build(version: "1.0.0", output_dir: tmpdir)

      expect(Dir.exist?(output)).to be true
      expect(File.exist?(File.join(output, "lib/pizzas_domain.rb"))).to be true

      FileUtils.rm_rf(tmpdir)
    end
  end

  describe "#inspect" do
    it "shows a readable summary" do
      workbench.aggregate("Pizza") { attribute :name, String }
      expect(workbench.inspect).to eq('#<Hecks::Workbench "Pizzas" [sketch] (1 aggregates)>')
    end
  end

  describe "#add_verb" do
    it "adds a custom verb" do
      workbench.add_verb("Poop")
      domain = workbench.to_domain
      expect(domain.custom_verbs).to include("Poop")
    end

    it "does not add duplicates" do
      workbench.add_verb("Poop")
      workbench.add_verb("Poop")
      domain = workbench.to_domain
      expect(domain.custom_verbs.count("Poop")).to eq(1)
    end
  end

  describe "#active_hecks!" do
    it "enables active_hecks mode" do
      workbench.aggregate "Pizza" do
        attribute :name, String
        command "CreatePizza" do
          attribute :name, String
        end
      end

      workbench.active_hecks!
      expect(workbench.active_hecks?).to be true
    end
  end

  describe "play mode" do
    before do
      workbench.aggregate "Pizza" do
        attribute :name, String
        command "CreatePizza" do
          attribute :name, String
        end
      end
    end

    it "switches to play mode" do
      workbench.play!
      expect(workbench).to be_play
    end

    it "switches back to sketch mode" do
      workbench.play!
      workbench.sketch!
      expect(workbench).to be_sketch
    end

    it "lists available commands" do
      workbench.play!
      expect(workbench.commands).to include(/CreatePizza.*CreatedPizza/)
    end

    it "executes commands in play mode" do
      workbench.play!
      mod = Object.const_get("PizzasDomain")
      mod::Pizza.create(name: "Pepperoni")
      expect(workbench.events.size).to eq(1)
    end

    it "refuses play mode for invalid domains" do
      bad_workbench = described_class.new("Bad")
      bad_workbench.aggregate "Order" do
        attribute :pizza_id, reference_to("Pizza")
        command "PlaceOrder" do
          attribute :pizza_id, reference_to("Pizza")
        end
      end

      bad_workbench.play!
      expect(bad_workbench).to be_sketch
    end

    it "shows play in inspect" do
      workbench.play!
      expect(workbench.inspect).to include("[play]")
    end
  end

  describe "#browse" do
    before do
      pizza = workbench.aggregate("Pizza")
      pizza.attr :name, String
      pizza.command("CreatePizza") { attribute :name, String }
      workbench.aggregate("Order")
    end

    it "prints a tree of all aggregates" do
      expect { workbench.browse }.to output(/Pizzas Domain.*Pizza.*Order/m).to_stdout
    end

    it "prints a single aggregate" do
      expect { workbench.browse("Pizza") }.to output(/Pizza.*attributes.*commands/m).to_stdout
    end
  end

  describe "#promote" do
    let(:tmpdir) { Dir.mktmpdir("hecks-promote-") }

    before do
      workbench.aggregate "Pizza" do
        attribute :name, String
        command "CreatePizza" do
          attribute :name, String
        end
      end

      workbench.aggregate "Comment" do
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
      workbench.promote("Comment")
      expect(File.exist?(File.join(tmpdir, "comment_domain.rb"))).to be true
      content = File.read(File.join(tmpdir, "comment_domain.rb"))
      expect(content).to include('Hecks.domain "Comment"')
      expect(content).to include('aggregate "Comment"')
      expect(content).to include('command "CreateComment"')
    end

    it "removes the promoted aggregate from the workbench" do
      workbench.promote("Comment")
      expect(workbench.aggregates).to eq(["Pizza"])
    end

    it "raises for unknown aggregate" do
      expect { workbench.promote("Nonexistent") }.to raise_error(RuntimeError, /No aggregate/)
    end
  end
end
