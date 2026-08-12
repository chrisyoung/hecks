require "spec_helper"

# Real coverage for the Stripe adapter registration: the CANONICAL
# PIZZAS EXAMPLE's own payment edge
# (pizzeria/domain/pizzas.hecksagon: "Order.charged_by('Stripe', on:
# 'OrderPlaced') do success 'Order.Authorize' failure 'Order.Decline'
# end"), but no `.port`/`.adapter` pair existed for it to resolve
# against -- a real bind naming it failed the wiring gate with "unknown
# adapter". Distinct from the pre-existing MockStripeAdapter (a
# different adapter name, a different "checkout" port, used for
# checkout-session smoke tests) -- this is the real payment/charged_by
# edge the canonical example's own narrative describes. The actual
# charge call is real, external, off-core handler machinery this
# registration only DECLARES the contract for.
RSpec.describe "the Stripe adapter and payment port" do
  def registry_with_real_library
    registry = Hecksagain::Runtime::Registry.new
    loading = Hecksagain::Ports::Loading.bootstrap
    Hecksagain.with_registry(registry) { loading.load_library }
    registry
  end

  it "resolves a charged_by bind naming Stripe without a WiringError" do
    registry = registry_with_real_library

    bind = Hecksagain::Bluebook::IR::Bind.new(
      aggregate: "Pizzas::Order", verb: "charged_by", adapter: "Stripe", role: nil
    )

    expect { registry.check_verb(bind) }.not_to raise_error
  end

  it "the payment port declares charged_by as an effect signal" do
    registry = registry_with_real_library

    port = registry.ports["payment"]
    expect(port.verb).to eq("charged_by")
    expect(port.effect?).to be(true)
  end

  it "does not collide with the pre-existing MockStripeAdapter/checkout port" do
    registry = registry_with_real_library

    expect(registry.ports["payment"]).not_to eq(registry.ports["checkout"])
    expect(registry.adapters["Stripe"]).not_to eq(registry.adapters["MockStripeAdapter"])
  end

  it "refuses a bind naming Stripe for the wrong verb" do
    registry = registry_with_real_library

    bind = Hecksagain::Bluebook::IR::Bind.new(
      aggregate: "Pizzas::Order", verb: "persisted_by", adapter: "Stripe", role: nil
    )

    expect { registry.check_verb(bind) }.to raise_error(
      Hecksagain::Runtime::WiringError, /Stripe implements the payment port.*cannot satisfy persisted_by/m
    )
  end
end
