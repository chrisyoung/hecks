require "spec_helper"

RSpec.describe Hecks::ValidationRules::Naming::SafeIdentifierNames do
  def validate(domain)
    v = Hecks::Validator.new(domain)
    [v.valid?, v.errors]
  end

  describe "aggregate names" do
    it "rejects a name containing a backtick" do
      domain = Hecks::DomainModel::Structure::Domain.new(
        name: "Pizzas",
        aggregates: [
          Hecks::DomainModel::Structure::Aggregate.new(
            name: "Pizza`Danger",
            commands: [
              Hecks::DomainModel::Behavior::Command.new(
                name: "CreatePizzaDanger",
                attributes: [Hecks::DomainModel::Structure::Attribute.new(name: :name, type: String)]
              )
            ]
          )
        ]
      )
      valid, errors = validate(domain)
      expect(valid).to be false
      expect(errors.any? { |e| e.include?("Pizza`Danger") }).to be true
    end

    it "rejects a name containing a double quote" do
      domain = Hecks::DomainModel::Structure::Domain.new(
        name: "Pizzas",
        aggregates: [
          Hecks::DomainModel::Structure::Aggregate.new(
            name: 'Pizza"Bad',
            commands: [
              Hecks::DomainModel::Behavior::Command.new(
                name: "CreatePizzaBad",
                attributes: [Hecks::DomainModel::Structure::Attribute.new(name: :name, type: String)]
              )
            ]
          )
        ]
      )
      valid, errors = validate(domain)
      expect(valid).to be false
      expect(errors.any? { |e| e.include?('Pizza"Bad') }).to be true
    end

    it "rejects a lowercase aggregate name" do
      domain = Hecks::DomainModel::Structure::Domain.new(
        name: "Pizzas",
        aggregates: [
          Hecks::DomainModel::Structure::Aggregate.new(
            name: "pizza",
            commands: [
              Hecks::DomainModel::Behavior::Command.new(
                name: "CreatePizza",
                attributes: [Hecks::DomainModel::Structure::Attribute.new(name: :name, type: String)]
              )
            ]
          )
        ]
      )
      valid, errors = validate(domain)
      expect(valid).to be false
      expect(errors.any? { |e| e.include?("pizza") && e.include?("aggregate") }).to be true
    end
  end

  describe "attribute names" do
    it "rejects an attribute name containing a semicolon" do
      domain = Hecks::DomainModel::Structure::Domain.new(
        name: "Pizzas",
        aggregates: [
          Hecks::DomainModel::Structure::Aggregate.new(
            name: "Pizza",
            attributes: [
              Hecks::DomainModel::Structure::Attribute.new(name: :"bad;name", type: String)
            ],
            commands: [
              Hecks::DomainModel::Behavior::Command.new(
                name: "CreatePizza",
                attributes: [Hecks::DomainModel::Structure::Attribute.new(name: :name, type: String)]
              )
            ]
          )
        ]
      )
      valid, errors = validate(domain)
      expect(valid).to be false
      expect(errors.any? { |e| e.include?("bad;name") }).to be true
    end

    it "rejects an attribute name starting with uppercase" do
      domain = Hecks::DomainModel::Structure::Domain.new(
        name: "Pizzas",
        aggregates: [
          Hecks::DomainModel::Structure::Aggregate.new(
            name: "Pizza",
            attributes: [
              Hecks::DomainModel::Structure::Attribute.new(name: :BadName, type: String)
            ],
            commands: [
              Hecks::DomainModel::Behavior::Command.new(
                name: "CreatePizza",
                attributes: [Hecks::DomainModel::Structure::Attribute.new(name: :name, type: String)]
              )
            ]
          )
        ]
      )
      valid, errors = validate(domain)
      expect(valid).to be false
      expect(errors.any? { |e| e.include?("BadName") }).to be true
    end
  end

  describe "domain names" do
    it "rejects a domain name containing a slash" do
      domain = Hecks::DomainModel::Structure::Domain.new(
        name: "Bad/Domain",
        aggregates: [
          Hecks::DomainModel::Structure::Aggregate.new(
            name: "Pizza",
            commands: [
              Hecks::DomainModel::Behavior::Command.new(
                name: "CreatePizza",
                attributes: [Hecks::DomainModel::Structure::Attribute.new(name: :name, type: String)]
              )
            ]
          )
        ]
      )
      valid, errors = validate(domain)
      expect(valid).to be false
      expect(errors.any? { |e| e.include?("Bad/Domain") }).to be true
    end

    it "rejects a lowercase domain name" do
      domain = Hecks::DomainModel::Structure::Domain.new(
        name: "pizzas",
        aggregates: [
          Hecks::DomainModel::Structure::Aggregate.new(
            name: "Pizza",
            commands: [
              Hecks::DomainModel::Behavior::Command.new(
                name: "CreatePizza",
                attributes: [Hecks::DomainModel::Structure::Attribute.new(name: :name, type: String)]
              )
            ]
          )
        ]
      )
      valid, errors = validate(domain)
      expect(valid).to be false
      expect(errors.any? { |e| e.include?("pizzas") && e.include?("domain") }).to be true
    end
  end

  describe "enum values" do
    it "rejects an enum value containing a space" do
      domain = Hecks::DomainModel::Structure::Domain.new(
        name: "Pizzas",
        aggregates: [
          Hecks::DomainModel::Structure::Aggregate.new(
            name: "Pizza",
            attributes: [
              Hecks::DomainModel::Structure::Attribute.new(
                name: :status,
                type: String,
                enum: ["active", "bad value!"]
              )
            ],
            commands: [
              Hecks::DomainModel::Behavior::Command.new(
                name: "CreatePizza",
                attributes: [Hecks::DomainModel::Structure::Attribute.new(name: :name, type: String)]
              )
            ]
          )
        ]
      )
      valid, errors = validate(domain)
      expect(valid).to be false
      expect(errors.any? { |e| e.include?("bad value!") }).to be true
    end
  end

  describe "invariant messages" do
    it "rejects a message containing a backtick" do
      domain = Hecks::DomainModel::Structure::Domain.new(
        name: "Pizzas",
        aggregates: [
          Hecks::DomainModel::Structure::Aggregate.new(
            name: "Pizza",
            invariants: [
              Hecks::DomainModel::Structure::Invariant.new(message: "name must not be `empty`")
            ],
            commands: [
              Hecks::DomainModel::Behavior::Command.new(
                name: "CreatePizza",
                attributes: [Hecks::DomainModel::Structure::Attribute.new(name: :name, type: String)]
              )
            ]
          )
        ]
      )
      valid, errors = validate(domain)
      expect(valid).to be false
      expect(errors.any? { |e| e.include?("backtick") && e.include?("Pizza") }).to be true
    end

    it "rejects a message with unbalanced double quotes" do
      domain = Hecks::DomainModel::Structure::Domain.new(
        name: "Pizzas",
        aggregates: [
          Hecks::DomainModel::Structure::Aggregate.new(
            name: "Pizza",
            invariants: [
              Hecks::DomainModel::Structure::Invariant.new(message: 'name must not be "empty')
            ],
            commands: [
              Hecks::DomainModel::Behavior::Command.new(
                name: "CreatePizza",
                attributes: [Hecks::DomainModel::Structure::Attribute.new(name: :name, type: String)]
              )
            ]
          )
        ]
      )
      valid, errors = validate(domain)
      expect(valid).to be false
      expect(errors.any? { |e| e.include?("unbalanced double quotes") }).to be true
    end
  end

  describe "valid domain" do
    it "passes all checks for a well-formed domain" do
      domain = Hecks.domain("Pizzas") do
        aggregate("Pizza") do
          attribute :name, String
          attribute :status, String, enum: ["active", "archived"]
          command("CreatePizza") { attribute :name, String }
        end
      end
      valid, errors = validate(domain)
      expect(valid).to be(true), "Expected valid domain but got: #{errors}"
    end
  end
end
