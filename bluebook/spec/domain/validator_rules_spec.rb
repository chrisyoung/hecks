require "spec_helper"

RSpec.describe "Validator DDD rules" do
  def validate(domain)
    validator = Hecks::Validator.new(domain)
    [validator.valid?, validator.errors]
  end

  describe "aggregate must have at least one command" do
    it "rejects aggregates with no commands" do
      domain = Hecks::DomainModel::Structure::Domain.new(
        name: "Bad",
        aggregates: [
          Hecks::DomainModel::Structure::Aggregate.new(
            name: "Widget",
            attributes: [Hecks::DomainModel::Structure::Attribute.new(name: :name, type: String)]
          )
        ]
      )

      valid, errors = validate(domain)
      expect(valid).to be false
      expect(errors).to include(/Widget has no commands/)
    end
  end

  describe "value objects can contain references" do
    it "allows value objects with reference_to" do
      domain = Hecks.domain "Refs" do
        aggregate "Pizza" do
          attribute :name, String

          value_object "Topping" do
            reference_to "Pizza"
          end

          command "CreatePizza" do
            attribute :name, String
          end
        end
      end

      valid, _errors = validate(domain)
      expect(valid).to be true
    end
  end

  describe "command names should be verb phrases" do
    it "warns when command name doesn't start with a verb" do
      domain = Hecks::DomainModel::Structure::Domain.new(
        name: "Bad",
        aggregates: [
          Hecks::DomainModel::Structure::Aggregate.new(
            name: "Pizza",
            attributes: [Hecks::DomainModel::Structure::Attribute.new(name: :name, type: String)],
            commands: [
              Hecks::DomainModel::Behavior::Command.new(
                name: "PizzaOrder",
                attributes: [Hecks::DomainModel::Structure::Attribute.new(name: :name, type: String)]
              )
            ],
            events: [Hecks::DomainModel::Behavior::DomainEvent.new(name: "PizzaOrdered", attributes: [])]
          )
        ]
      )

      valid, errors = validate(domain)
      expect(valid).to be false
      expect(errors).to include(/PizzaOrder.*doesn't start with a verb/)
    end

    it "accepts commands starting with recognized verbs" do
      domain = Hecks.domain "Good" do
        aggregate "Pizza" do
          attribute :name, String
          command "CreatePizza" do
            attribute :name, String
          end
        end
      end

      valid, _ = validate(domain)
      expect(valid).to be true
    end
  end

  describe "no self-references" do
    it "rejects an aggregate that references itself" do
      domain = Hecks.domain "Bad" do
        aggregate "Pizza" do
          reference_to "Pizza"
          command "CreatePizza" do
            attribute :name, String
          end
        end
      end

      valid, errors = validate(domain)
      expect(valid).to be false
      expect(errors).to include(/Pizza references itself/)
    end
  end

  describe "policy trigger must name an existing command" do
    it "rejects policies that trigger unknown commands" do
      domain = Hecks.domain "Bad" do
        aggregate "Order" do
          attribute :quantity, Integer
          command "PlaceOrder" do
            attribute :quantity, Integer
          end

          policy "DoSomething" do
            on "PlacedOrder"
            trigger "NonExistentCommand"
          end
        end
      end

      valid, errors = validate(domain)
      expect(valid).to be false
      expect(errors).to include(/triggers unknown command: NonExistentCommand/)
    end

    it "accepts policies that trigger existing commands" do
      domain = Hecks.domain "Good" do
        aggregate "Order" do
          attribute :quantity, Integer
          command "PlaceOrder" do
            attribute :quantity, Integer
          end
          command "ReserveStock" do
            attribute :quantity, Integer
          end

          policy "Reserve" do
            on "PlacedOrder"
            trigger "ReserveStock"
          end
        end
      end

      valid, _ = validate(domain)
      expect(valid).to be true
    end
  end

  describe "aggregate and value object name collision" do
    it "rejects when a value object has the same name as its aggregate" do
      domain = Hecks::DomainModel::Structure::Domain.new(
        name: "Bad",
        aggregates: [
          Hecks::DomainModel::Structure::Aggregate.new(
            name: "Pizza",
            attributes: [Hecks::DomainModel::Structure::Attribute.new(name: :name, type: String)],
            value_objects: [
              Hecks::DomainModel::Structure::ValueObject.new(name: "Pizza", attributes: [])
            ],
            commands: [
              Hecks::DomainModel::Behavior::Command.new(
                name: "CreatePizza",
                attributes: [Hecks::DomainModel::Structure::Attribute.new(name: :name, type: String)]
              )
            ],
            events: [Hecks::DomainModel::Behavior::DomainEvent.new(name: "CreatedPizza", attributes: [])]
          )
        ]
      )

      valid, errors = validate(domain)
      expect(valid).to be false
      expect(errors).to include(/Pizza has a value object with the same name/)
    end
  end

  describe "references must target aggregate roots" do
    it "rejects references to value objects" do
      domain = Hecks.domain "Bad" do
        aggregate "Pizza" do
          attribute :name, String
          reference_to "Topping"

          value_object "Topping" do
            attribute :name, String
          end

          command "CreatePizza" do
            attribute :name, String
          end
        end
      end

      valid, errors = validate(domain)
      expect(valid).to be false
      expect(errors).to include(/references Topping which is a value object/)
    end
  end
end
