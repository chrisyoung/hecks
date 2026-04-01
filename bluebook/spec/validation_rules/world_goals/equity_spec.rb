require "spec_helper"

RSpec.describe "World Goals :equity validation rule" do
  describe "Equity validator" do
    it "warns about pricing attributes without documented invariants or policies" do
      domain = Hecks.domain "PricingUndocumented" do
        world_goals :equity
        aggregate "Service" do
          attribute :name, String
          attribute :price, Float
          command "CreateService" do
            attribute :name, String
            attribute :price, Float
          end
        end
      end

      validator = Hecks::Validator.new(domain)
      validator.valid?
      warnings = validator.warnings
      expect(warnings).to include(/Equity.*Service.*pricing attributes.*no documented invariant or policy/)
    end

    it "does not warn when pricing is documented with invariants" do
      domain = Hecks.domain "PricingDocumented" do
        world_goals :equity
        aggregate "Service" do
          attribute :name, String
          attribute :price, Float
          attribute :cost, Float
          invariant "price must be at least cost times 1.2" do
            # price >= cost * 1.2
          end
          command "CreateService" do
            attribute :name, String
            attribute :price, Float
            attribute :cost, Float
          end
        end
      end

      validator = Hecks::Validator.new(domain)
      warnings = validator.warnings
      expect(warnings).not_to include(/Equity.*Service/)
    end

    it "does not warn when pricing is documented with policies" do
      domain = Hecks.domain "PricingWithPolicy" do
        world_goals :equity
        aggregate "Subscription" do
          attribute :rate, Float
          policy "ApplyAnnualRateDiscount" do
            on "SubscriptionCreated"
            trigger "ApplyDiscount"
          end
          command "CreateSubscription" do
            attribute :rate, Float
          end
        end
      end

      validator = Hecks::Validator.new(domain)
      warnings = validator.warnings
      expect(warnings).not_to include(/Equity.*Subscription/)
    end

    it "detects all pricing-related attribute names" do
      domain = Hecks.domain "MultiplePricing" do
        world_goals :equity
        aggregate "Product" do
          attribute :price, Float
          attribute :cost, Float
          attribute :fee, Float
          attribute :rate, Float
          attribute :charge, Float
          attribute :amount, Float
          attribute :margin, Float
          attribute :discount, Float
          attribute :markup, Float
          command "CreateProduct" do
            attribute :price, Float
          end
        end
      end

      validator = Hecks::Validator.new(domain)
      validator.valid?
      warnings = validator.warnings
      expect(warnings).to include(/Equity.*Product.*pricing attributes/)
    end

    it "does not warn when no pricing attributes present" do
      domain = Hecks.domain "NoPricing" do
        world_goals :equity
        aggregate "Article" do
          attribute :title, String
          attribute :content, String
          command "PublishArticle" do
            attribute :title, String
          end
        end
      end

      validator = Hecks::Validator.new(domain)
      warnings = validator.warnings
      expect(warnings).not_to include(/Equity/)
    end

    it "does not warn when equity goal is not declared" do
      domain = Hecks.domain "NoEquityGoal" do
        aggregate "Product" do
          attribute :price, Float
          command "CreateProduct" do
            attribute :price, Float
          end
        end
      end

      validator = Hecks::Validator.new(domain)
      validator.valid?
      warnings = validator.warnings
      expect(warnings).not_to include(/Equity/)
    end
  end
end
