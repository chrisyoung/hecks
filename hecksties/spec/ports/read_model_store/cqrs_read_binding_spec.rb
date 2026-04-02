require "spec_helper"
require "hecks/ports/read_model_store"
require "hecks/ports/read_model_store/cqrs_read_binding"

RSpec.describe Hecks::CqrsReadBinding do
  let(:domain) do
    Hecks.domain "CrbTest" do
      aggregate "Gadget" do
        attribute :label, String
        command "CreateGadget" do
          attribute :label, String
        end
      end
    end
  end

  it "rebinds find, all, count to the read repo" do
    app = Hecks.load(domain)

    read_adapter = CrbTestDomain::Adapters::GadgetMemoryRepository.new
    described_class.bind(CrbTestDomain::Gadget, read_adapter)

    # Write to the write repo directly
    gadget = CrbTestDomain::Gadget.create(label: "Whirligig")

    # The write repo has data but the read adapter is empty
    expect(read_adapter.all).to be_empty
    expect(app["Gadget"].all.size).to eq(1)

    # Reads route to the empty read adapter
    expect(CrbTestDomain::Gadget.all).to be_empty
    expect(CrbTestDomain::Gadget.count).to eq(0)

    # Sync to read adapter
    read_adapter.save(gadget)

    # Now reads see it
    expect(CrbTestDomain::Gadget.all.size).to eq(1)
    expect(CrbTestDomain::Gadget.find(gadget.id).label).to eq("Whirligig")
  end

  it "binds where and find_by via AdHocQueries" do
    app = Hecks.load(domain)

    read_adapter = CrbTestDomain::Adapters::GadgetMemoryRepository.new
    described_class.bind(CrbTestDomain::Gadget, read_adapter)

    gadget = CrbTestDomain::Gadget.create(label: "Doodad")
    read_adapter.save(gadget)

    expect(CrbTestDomain::Gadget.where(label: "Doodad").count).to eq(1)
    expect(CrbTestDomain::Gadget.find_by(label: "Doodad").label).to eq("Doodad")
  end
end
