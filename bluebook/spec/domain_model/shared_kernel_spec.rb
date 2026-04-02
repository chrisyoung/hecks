require "spec_helper"

RSpec.describe "Shared Kernel Types (HEC-77)" do
  before { Hecks::SharedKernelRegistry.clear }

  let(:kernel_domain) do
    Hecks.domain "SharedTypes" do
      shared_kernel

      aggregate "Types" do
        attribute :placeholder, String

        value_object "Money" do
          attribute :amount, Integer
          attribute :currency, String
        end

        value_object "DateRange" do
          attribute :start_date, String
          attribute :end_date, String
        end

        command "CreateTypes" do
          attribute :placeholder, String
        end
      end
    end
  end

  let(:consumer_domain) do
    Hecks.domain "Billing" do
      uses_kernel "SharedTypes"

      aggregate "Invoice" do
        attribute :total, Integer
        command "CreateInvoice" do
          attribute :total, Integer
        end
      end
    end
  end

  describe "SharedKernelRegistry" do
    it "registers and looks up kernel domains" do
      Hecks::SharedKernelRegistry.register("SharedTypes", kernel_domain)
      expect(Hecks::SharedKernelRegistry.lookup("SharedTypes")).to eq(kernel_domain)
    end

    it "returns kernel value object types" do
      Hecks::SharedKernelRegistry.register("SharedTypes", kernel_domain)
      types = Hecks::SharedKernelRegistry.kernel_types("SharedTypes")
      expect(types.map(&:name)).to contain_exactly("Money", "DateRange")
    end

    it "returns empty array for unknown kernels" do
      expect(Hecks::SharedKernelRegistry.kernel_types("Unknown")).to eq([])
    end
  end

  describe "domain IR" do
    it "marks domain as shared kernel" do
      expect(kernel_domain).to be_shared_kernel
    end

    it "stores uses_kernels on consumer domain" do
      expect(consumer_domain.uses_kernels).to eq(["SharedTypes"])
    end
  end

  describe "InMemoryLoader with kernels" do
    it "creates type aliases in the consumer namespace" do
      # Load the kernel domain first
      Hecks::SharedKernelRegistry.register("SharedTypes", kernel_domain)
      Hecks.load(kernel_domain)

      # Now load the consumer domain
      Hecks.load(consumer_domain)

      # The consumer domain should have aliases to kernel types
      expect(BillingDomain::Money).to eq(SharedTypesDomain::Types::Money)
      expect(BillingDomain::DateRange).to eq(SharedTypesDomain::Types::DateRange)
    end
  end

  describe "DSL serialization" do
    it "serializes shared_kernel declaration" do
      source = Hecks::DslSerializer.new(kernel_domain).serialize
      expect(source).to include("shared_kernel")
    end

    it "serializes uses_kernel declaration" do
      source = Hecks::DslSerializer.new(consumer_domain).serialize
      expect(source).to include('uses_kernel "SharedTypes"')
    end
  end
end
