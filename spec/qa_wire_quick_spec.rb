require "spec_helper"

RSpec.describe "Wire domain - quick bug discovery" do
  WIRE_BLUEBOOK = File.join(InMemoryDomain::ROOT, "spec/fixtures/settlement.bluebook")

  def boot_wire
    registry = Hecksagain::Runtime::Registry.new
    Hecksagain.with_registry(registry) do
      Kernel.load(InMemoryDomain::PERSISTENCE_PORT)
      Kernel.load(InMemoryDomain::EXTRACTION_PORT)
      Kernel.load(InMemoryDomain::MEMORY_ADAPTER)
      Kernel.load(InMemoryDomain::PRISM_ADAPTER)
      Kernel.load(WIRE_BLUEBOOK)
      Hecksagain::Runtime::Loader.bind_runtime(Hecksagain::Runtime::Dispatcher.new(registry))
    end
  end

  it "Open drawer and Put money" do
    runtime = boot_wire
    runtime.dispatch("Wire::Drawer.Open", number: { value: "D001" })
    expect {
      runtime.dispatch("Wire::Drawer.Put",
        id: "D001",
        amount: { cents: 1000 })
    }.not_to raise_error
  end

  it "POTENTIAL BUG: Take from shut drawer" do
    runtime = boot_wire
    runtime.dispatch("Wire::Drawer.Open", number: { value: "D002" })
    runtime.dispatch("Wire::Drawer.Put", id: "D002", amount: { cents: 500 })
    runtime.dispatch("Wire::Drawer.Shut", id: "D002")

    error = nil
    begin
      runtime.dispatch("Wire::Drawer.Take",
        id: "D002",
        amount: { cents: 100 })
    rescue => e
      error = e
    end

    if error
      puts "✓ Wire rejects Take from shut drawer"
    else
      puts "🐛 BUG #2: Wire allows Take from shut drawer!"
    end
  end

  it "POTENTIAL BUG: Take more than available" do
    runtime = boot_wire
    runtime.dispatch("Wire::Drawer.Open", number: { value: "D003" })
    runtime.dispatch("Wire::Drawer.Put", id: "D003", amount: { cents: 100 })

    error = nil
    begin
      runtime.dispatch("Wire::Drawer.Take",
        id: "D003",
        amount: { cents: 500 })
    rescue => e
      error = e
    end

    if error
      puts "✓ Wire rejects Take exceeding balance"
    else
      puts "🐛 BUG #3: Wire allows negative drawer balance!"
    end
  end

  it "POTENTIAL BUG: Result aggregate not frozen" do
    runtime = boot_wire
    result = runtime.dispatch("Wire::Drawer.Open", number: { value: "D004" })

    if result.frozen?
      puts "✓ Wire results are frozen"
    else
      puts "🐛 BUG #4: Wire results not frozen (mutation vulnerability)"
    end
  end
end
