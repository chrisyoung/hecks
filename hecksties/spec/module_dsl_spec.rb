require "spec_helper"

RSpec.describe Hecks::ModuleDSL do
  let(:test_module) do
    m = Module.new do
      extend Hecks::ModuleDSL
      lazy_registry :widgets
      lazy_registry(:items) { [] }
      lazy_registry(:secret, private: true)
    end

    mod = Module.new
    mod.extend(m)
    mod
  end

  it "creates a hash registry by default" do
    expect(test_module.widgets).to eq({})
  end

  it "supports custom default via block" do
    expect(test_module.items).to eq([])
  end

  it "returns the same instance on repeated access" do
    test_module.widgets[:foo] = :bar
    expect(test_module.widgets[:foo]).to eq(:bar)
  end

  it "supports private registries" do
    expect { test_module.secret }.to raise_error(NoMethodError)
  end
end
