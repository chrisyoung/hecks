require "spec_helper"

RSpec.describe "Shared Kernel" do
  before(:all) do
    Hecksagon::SharedKernelRegistry.clear!

    @pricing = Hecks.domain "Pricing" do
      shared_kernel
      expose_types "Money"

      aggregate "Rate" do
        attribute :amount, Integer
        attribute :currency, String

        value_object "Money" do
          attribute :cents, Integer
          attribute :currency, String
        end

        command "CreateRate" do
          attribute :amount, Integer
          attribute :currency, String
        end
      end
    end

    @orders = Hecks.domain "Orders" do
      uses_kernel "Pricing"

      aggregate "Order" do
        attribute :customer_name, String
        attribute :total_cents, Integer

        command "PlaceOrder" do
          attribute :customer_name, String
          attribute :total_cents, Integer
        end
      end
    end

    @pricing_rt = Hecks.load(@pricing, force: true)
    @orders_rt = Hecks.load(@orders, force: true)
  end

  after(:all) do
    Hecksagon::SharedKernelRegistry.clear!
  end

  describe "SharedKernelRegistry" do
    it "registers a domain as shared kernel on build" do
      expect(Hecksagon::SharedKernelRegistry.kernel?("Pricing")).to be true
    end

    it "stores exposed type names" do
      expect(Hecksagon::SharedKernelRegistry.types_for("Pricing")).to eq(["Money"])
    end

    it "returns empty for non-kernel domains" do
      expect(Hecksagon::SharedKernelRegistry.types_for("Orders")).to eq([])
    end

    it "does not register consumer domains as kernels" do
      expect(Hecksagon::SharedKernelRegistry.kernel?("Orders")).to be false
    end
  end

  describe "Domain IR" do
    it "marks kernel domain as shared_kernel" do
      expect(@pricing.shared_kernel?).to be true
    end

    it "records exposed types on the domain" do
      expect(@pricing.shared_kernel_types).to eq(["Money"])
    end

    it "records uses_kernels on the consumer domain" do
      expect(@orders.uses_kernels).to eq(["Pricing"])
    end
  end

  describe "InMemoryLoader kernel aliases" do
    it "creates alias for Money in the consumer domain module" do
      expect(OrdersDomain.const_defined?(:Money)).to be true
    end

    it "aliases to the source domain type" do
      expect(OrdersDomain::Money).to eq(PricingDomain::Rate::Money)
    end

    it "allows constructing the shared type via the alias" do
      money = OrdersDomain::Money.new(cents: 999, currency: "USD")
      expect(money.cents).to eq(999)
      expect(money.currency).to eq("USD")
    end
  end

  describe "auto-expose when no explicit types given" do
    before(:all) do
      Hecksagon::SharedKernelRegistry.clear!

      @common = Hecks.domain "Common" do
        shared_kernel

        aggregate "Shared" do
          attribute :label, String

          value_object "Address" do
            attribute :street, String
            attribute :city, String
          end

          value_object "PhoneNumber" do
            attribute :digits, String
          end

          command "CreateShared" do
            attribute :label, String
          end
        end
      end

      Hecks.load(@common, force: true)
    end

    it "exposes all value objects and entities when no explicit types" do
      types = Hecksagon::SharedKernelRegistry.types_for("Common")
      expect(types).to include("Address", "PhoneNumber")
    end
  end
end
