require "spec_helper"

RSpec.describe "DslSerializer destructive tests" do
  describe "validations round-trip" do
    it "preserves validation rules through serialize -> eval -> serialize" do
      domain = Hecks.domain "ValDomain" do
        aggregate "User" do
          attribute :name, String
          attribute :email, String

          validation :name, presence: true
          validation :email, presence: true, format: /@/

          command "CreateUser" do
            attribute :name, String
            attribute :email, String
          end
        end
      end

      source1 = Hecks::DslSerializer.new(domain).serialize
      restored = eval(source1)
      source2 = Hecks::DslSerializer.new(restored).serialize

      expect(source1).to eq(source2), "Round-trip produced different DSL:\n--- original ---\n#{source1}\n--- restored ---\n#{source2}"
      expect(restored.aggregates.first.validations.size).to eq(2)
      expect(restored.aggregates.first.validations.map(&:field)).to eq([:name, :email])
    end

    it "preserves complex validation rules (regex)" do
      domain = Hecks.domain "RegexVal" do
        aggregate "Thing" do
          attribute :code, String
          validation :code, format: /\A[A-Z]{3}\z/
          command "CreateThing" do
            attribute :code, String
          end
        end
      end

      source = Hecks::DslSerializer.new(domain).serialize
      restored = eval(source)
      rules = restored.aggregates.first.validations.first.rules
      expect(rules[:format]).to be_a(Regexp)
      expect("ABC").to match(rules[:format])
      expect("abc").not_to match(rules[:format])
    end
  end

  describe "scopes round-trip" do
    it "preserves hash scopes through round-trip" do
      domain = Hecks.domain "ScopeDomain" do
        aggregate "Product" do
          attribute :name, String
          attribute :status, String

          scope :active, status: "active"
          scope :draft, status: "draft"

          command "CreateProduct" do
            attribute :name, String
            attribute :status, String
          end
        end
      end

      source1 = Hecks::DslSerializer.new(domain).serialize
      restored = eval(source1)
      source2 = Hecks::DslSerializer.new(restored).serialize

      expect(source1).to eq(source2), "Scope round-trip failed:\n--- original ---\n#{source1}\n--- restored ---\n#{source2}"
      expect(restored.aggregates.first.scopes.size).to eq(2)
    end

    it "silently drops callable (lambda) scopes — they cannot be serialized" do
      domain = Hecks.domain "LambdaScope" do
        aggregate "Item" do
          attribute :name, String
          attribute :price, Float

          scope :active, status: "active"
          scope :cheap, ->(max) { { price: max } }

          command "CreateItem" do
            attribute :name, String
            attribute :price, Float
          end
        end
      end

      source = Hecks::DslSerializer.new(domain).serialize
      expect(source).not_to include("cheap")
      expect(source).to include("scope :active")

      restored = eval(source)
      # Lambda scope was lost — only hash scope survives
      expect(restored.aggregates.first.scopes.size).to eq(1)
      expect(domain.aggregates.first.scopes.size).to eq(2)
    end
  end

  describe "queries round-trip" do
    it "FAILS: queries are completely lost during serialization" do
      domain = Hecks.domain "QueryDomain" do
        aggregate "Order" do
          attribute :total, Float
          attribute :status, String

          query "HighValueOrders" do
            where(total: gt(100.0))
          end

          command "CreateOrder" do
            attribute :total, Float
            attribute :status, String
          end
        end
      end

      source = Hecks::DslSerializer.new(domain).serialize
      # Queries should appear in serialized output but they DON'T
      expect(source).to include("query"), "BUG: queries are silently dropped during serialization. Source:\n#{source}"
    end
  end

  describe "aggregate-level invariants round-trip" do
    it "FAILS: aggregate invariants are lost (only value_object invariants are serialized)" do
      domain = Hecks.domain "InvDomain" do
        aggregate "Account" do
          attribute :balance, Float

          invariant "balance must be non-negative" do
            balance >= 0
          end

          command "CreateAccount" do
            attribute :balance, Float
          end
        end
      end

      source = Hecks::DslSerializer.new(domain).serialize
      # The serializer only handles value_object invariants, not aggregate invariants
      expect(source).to include("invariant"), "BUG: aggregate-level invariants are silently dropped. Source:\n#{source}"
    end
  end

  describe "policies round-trip" do
    it "preserves policy event_name and trigger_command" do
      domain = Hecks.domain "PolicyDomain" do
        aggregate "Order" do
          attribute :total, Float

          command "PlaceOrder" do
            attribute :total, Float
          end

          command "SendConfirmation" do
            attribute :total, Float
          end

          policy "NotifyOnOrder" do
            on "PlacedOrder"
            trigger "SendConfirmation"
          end
        end
      end

      source = Hecks::DslSerializer.new(domain).serialize
      expect(source).to include('policy "NotifyOnOrder"')
      expect(source).to include('on "PlacedOrder"')
      expect(source).to include('trigger "SendConfirmation"')

      restored = eval(source)
      pol = restored.aggregates.first.policies.first
      expect(pol.name).to eq("NotifyOnOrder")
      expect(pol.event_name).to eq("PlacedOrder")
      expect(pol.trigger_command).to eq("SendConfirmation")

      # Full round-trip
      source2 = Hecks::DslSerializer.new(restored).serialize
      expect(source).to eq(source2)
    end
  end

  describe "JSON attribute type round-trip" do
    it "preserves JSON type through serialization" do
      domain = Hecks.domain "JsonDomain" do
        aggregate "Config" do
          attribute :settings, JSON
          attribute :name, String

          command "CreateConfig" do
            attribute :settings, JSON
            attribute :name, String
          end
        end
      end

      source = Hecks::DslSerializer.new(domain).serialize
      expect(source).to include("attribute :settings, JSON")

      restored = eval(source)
      settings_attr = restored.aggregates.first.attributes.find { |a| a.name == :settings }
      expect(settings_attr.type).to eq(JSON)
      expect(settings_attr.json?).to be true
    end
  end

  describe "list_of and reference_to round-trip" do
    it "preserves list_of wrapper through round-trip" do
      domain = Hecks.domain "ListDomain" do
        aggregate "Team" do
          attribute :name, String
          attribute :members, list_of("Member")

          value_object "Member" do
            attribute :name, String
          end

          command "CreateTeam" do
            attribute :name, String
          end
        end
      end

      source = Hecks::DslSerializer.new(domain).serialize
      expect(source).to include('list_of("Member")')

      restored = eval(source)
      members_attr = restored.aggregates.first.attributes.find { |a| a.name == :members }
      expect(members_attr.list?).to be true
      expect(members_attr.type).to eq("Member")
    end

    it "preserves reference_to wrapper through round-trip" do
      domain = Hecks.domain "RefDomain" do
        aggregate "Comment" do
          attribute :body, String
          attribute :post_id, reference_to("Post")

          command "CreateComment" do
            attribute :body, String
            attribute :post_id, reference_to("Post")
          end
        end
      end

      source = Hecks::DslSerializer.new(domain).serialize
      expect(source).to include('reference_to("Post")')

      restored = eval(source)
      ref_attr = restored.aggregates.first.attributes.find { |a| a.name == :post_id }
      expect(ref_attr.reference?).to be true
      expect(ref_attr.type).to eq("Post")

      # Full string equality round-trip
      source2 = Hecks::DslSerializer.new(restored).serialize
      expect(source).to eq(source2)
    end
  end

  describe "full serialize -> eval -> serialize identity" do
    it "produces identical output on second serialization (simple domain)" do
      domain = Hecks.domain "Identity1" do
        aggregate "Widget" do
          attribute :name, String
          attribute :weight, Float

          validation :name, presence: true

          scope :heavy, weight: 100.0

          command "CreateWidget" do
            attribute :name, String
            attribute :weight, Float
          end
        end
      end

      source1 = Hecks::DslSerializer.new(domain).serialize
      restored = eval(source1)
      source2 = Hecks::DslSerializer.new(restored).serialize

      expect(source1).to eq(source2), "Identity check failed:\n--- pass 1 ---\n#{source1}\n--- pass 2 ---\n#{source2}"
    end

    it "produces identical output on second serialization (multi-aggregate with value objects)" do
      domain = Hecks.domain "Identity2" do
        aggregate "Pizza" do
          attribute :name, String
          attribute :price, Float
          attribute :toppings, list_of("Topping")

          value_object "Topping" do
            attribute :label, String
            attribute :extra_cost, Float
          end

          validation :name, presence: true
          scope :cheap, price: 5.0

          command "CreatePizza" do
            attribute :name, String
            attribute :price, Float
          end

          policy "AutoDiscount" do
            on "CreatedPizza"
            trigger "ApplyDiscount"
          end

          command "ApplyDiscount" do
            attribute :name, String
          end
        end

        aggregate "Order" do
          attribute :pizza_id, reference_to("Pizza")
          attribute :quantity, Integer

          command "PlaceOrder" do
            attribute :pizza_id, reference_to("Pizza")
            attribute :quantity, Integer
          end
        end
      end

      source1 = Hecks::DslSerializer.new(domain).serialize
      restored = eval(source1)
      source2 = Hecks::DslSerializer.new(restored).serialize

      expect(source1).to eq(source2), "Multi-aggregate identity failed:\n--- pass 1 ---\n#{source1}\n--- pass 2 ---\n#{source2}"
    end
  end

  describe "edge cases" do
    it "handles aggregate with no commands" do
      domain = Hecks.domain "NoCmds" do
        aggregate "ReadOnly" do
          attribute :name, String
        end
      end

      source = Hecks::DslSerializer.new(domain).serialize
      expect(source).to include('aggregate "ReadOnly"')
      expect(source).to include("attribute :name, String")

      restored = eval(source)
      expect(restored.aggregates.first.name).to eq("ReadOnly")
    end

    it "handles empty aggregate" do
      domain = Hecks.domain "Empty" do
        aggregate "Blank" do
        end
      end

      source = Hecks::DslSerializer.new(domain).serialize
      restored = eval(source)
      expect(restored.aggregates.first.name).to eq("Blank")
      expect(restored.aggregates.first.attributes).to be_empty
    end

    it "handles value_object with no attributes" do
      domain = Hecks.domain "EmptyVO" do
        aggregate "Thing" do
          attribute :name, String
          value_object "EmptyValue" do
          end
          command "CreateThing" do
            attribute :name, String
          end
        end
      end

      source = Hecks::DslSerializer.new(domain).serialize
      expect(source).to include('value_object "EmptyValue"')
      restored = eval(source)
      expect(restored.aggregates.first.value_objects.first.name).to eq("EmptyValue")
    end

    it "handles command with read_model, external, and actor" do
      domain = Hecks.domain "FullCmd" do
        aggregate "Order" do
          attribute :total, Float

          command "ProcessPayment" do
            attribute :total, Float
            read_model "OrderSummary"
            external "PaymentGateway"
            actor "Customer"
          end
        end
      end

      source = Hecks::DslSerializer.new(domain).serialize
      expect(source).to include('read_model "OrderSummary"')
      expect(source).to include('external "PaymentGateway"')
      expect(source).to include('actor "Customer"')

      restored = eval(source)
      cmd = restored.aggregates.first.commands.first
      expect(cmd.read_models.map(&:name)).to eq(["OrderSummary"])
      expect(cmd.external_systems.map(&:name)).to eq(["PaymentGateway"])
      expect(cmd.actors.map(&:name)).to eq(["Customer"])
    end

    it "handles Integer and Float types correctly in serialization" do
      domain = Hecks.domain "TypesDomain" do
        aggregate "Metric" do
          attribute :count, Integer
          attribute :ratio, Float
          attribute :label, String

          command "CreateMetric" do
            attribute :count, Integer
            attribute :ratio, Float
            attribute :label, String
          end
        end
      end

      source = Hecks::DslSerializer.new(domain).serialize
      expect(source).to include("attribute :count, Integer")
      expect(source).to include("attribute :ratio, Float")
      expect(source).to include("attribute :label, String")

      restored = eval(source)
      attrs = restored.aggregates.first.attributes
      expect(attrs.find { |a| a.name == :count }.type).to eq(Integer)
      expect(attrs.find { |a| a.name == :ratio }.type).to eq(Float)
      expect(attrs.find { |a| a.name == :label }.type).to eq(String)
    end

    it "handles scope with numeric condition values" do
      domain = Hecks.domain "NumScope" do
        aggregate "Item" do
          attribute :price, Float
          attribute :qty, Integer

          scope :free, price: 0.0
          scope :single, qty: 1

          command "CreateItem" do
            attribute :price, Float
            attribute :qty, Integer
          end
        end
      end

      source = Hecks::DslSerializer.new(domain).serialize
      restored = eval(source)
      source2 = Hecks::DslSerializer.new(restored).serialize
      expect(source).to eq(source2), "Numeric scope round-trip failed:\n#{source}\nvs\n#{source2}"
    end

    it "handles multiple validations on the same field" do
      domain = Hecks.domain "MultiVal" do
        aggregate "User" do
          attribute :age, Integer
          validation :age, presence: true
          validation :age, numericality: { greater_than: 0 }
          command "CreateUser" do
            attribute :age, Integer
          end
        end
      end

      source = Hecks::DslSerializer.new(domain).serialize
      restored = eval(source)
      expect(restored.aggregates.first.validations.size).to eq(2)
    end
  end
end
