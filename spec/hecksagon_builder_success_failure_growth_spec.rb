require "spec_helper"
require "tempfile"

# Real coverage for HecksagonBuilder#success/#failure: a documented,
# structural-only stub for the EFFECT-family async-verdict shape the
# Pizzas example itself documents as canonical --
#
#   Order.charged_by("Stripe", on: "OrderPlaced") do
#     success "Order.Authorize"
#     failure "Order.Decline"
#   end
#
# -- which has NO implementation anywhere in hecksagain. Before this,
# a hecksagon that used this shape (miette's dream.hecksagon:
# `BodyDream::Dream.imaged_by("DreamImage", on: "DreamImageRequested")
# do success "Dream.RecordImage" end`) raised a plain NoMethodError on
# `success`, because BindingProxy#method_missing calls the trailing
# block WITHOUT instance_eval -- it runs in the block's own original
# lexical scope, which (inside `Hecks.hecksagon "X" do ... end`, itself
# `instance_eval`'d against a HecksagonBuilder) is the HecksagonBuilder
# instance, not the BindingProxy that recorded the bind.
#
# This PR captures the shape structurally so the file boots -- NOT a
# real fix. `on:` is silently dropped by BindingProxy#method_missing
# (pre-existing, untouched by this PR); success/failure's own command
# names are accepted and discarded. That is an honest, documented gap,
# not silently pretended complete.
RSpec.describe "HecksagonBuilder#success/#failure (async-verdict stub)" do
  def boot(source, hecksagon_name, &binds)
    file = Tempfile.new(["hecksagon-success-failure-growth-", ".bluebook"])
    file.write(source)
    file.flush

    previous = ENV["HECKSAGAIN_META_VALIDATION"]
    ENV["HECKSAGAIN_META_VALIDATION"] = "off"

    registry = Hecksagain::Runtime::Registry.new
    Hecksagain.with_registry(registry) do
      Kernel.load(InMemoryDomain::PERSISTENCE_PORT)
      Kernel.load(InMemoryDomain::EXTRACTION_PORT)
      Kernel.load(InMemoryDomain::MEMORY_ADAPTER)
      Kernel.load(InMemoryDomain::PRISM_ADAPTER)
      Kernel.eval(source, TOPLEVEL_BINDING, file.path, 1)
      Hecks.hecksagon(hecksagon_name, &binds)
    end
    registry
  ensure
    ENV["HECKSAGAIN_META_VALIDATION"] = previous
    file&.close!
  end

  ASYNC_VERDICT_SOURCE = <<~BLUEBOOK
    Hecks.bluebook "AsyncVerdictGrowth" do
      aggregate "Order" do
        identified_by { order_id.value }

        value_object "OrderId" do
          attribute :value, String
        end

        attribute :order_id, OrderId

        command "Authorize" do
          attribute :order_id, OrderId
          emits "OrderAuthorized"
        end

        command "Decline" do
          attribute :order_id, OrderId
          emits "OrderDeclined"
        end
      end
    end
  BLUEBOOK

  it "boots a hecksagon using the canonical charged_by/on/success/failure shape without raising" do
    expect do
      boot(ASYNC_VERDICT_SOURCE, "AsyncVerdictGrowth") do
        ::AsyncVerdictGrowth::Order.charged_by("Stripe", on: "OrderPlaced") do
          success "AsyncVerdictGrowth::Order.Authorize"
          failure "AsyncVerdictGrowth::Order.Decline"
        end
      end
    end.not_to raise_error
  end

  it "still records the real charged_by bind, on: dropped (pre-existing, untouched by this stub)" do
    registry = boot(ASYNC_VERDICT_SOURCE, "AsyncVerdictGrowth") do
      ::AsyncVerdictGrowth::Order.charged_by("Stripe", on: "OrderPlaced") do
        success "AsyncVerdictGrowth::Order.Authorize"
        failure "AsyncVerdictGrowth::Order.Decline"
      end
    end

    bind = registry.hecksagon("AsyncVerdictGrowth").bind_for("Order", "charged_by")
    expect(bind).not_to be_nil
    expect(bind.adapter).to eq("Stripe")
  end

  it "success/failure are no-ops -- accepted, not stored or dispatched anywhere" do
    builder = Hecksagain::Bluebook::DSL::HecksagonBuilder.new("AsyncVerdictGrowth")
    expect(builder.success("AsyncVerdictGrowth::Order.Authorize")).to be_nil
    expect(builder.failure("AsyncVerdictGrowth::Order.Decline")).to be_nil
  end
end
