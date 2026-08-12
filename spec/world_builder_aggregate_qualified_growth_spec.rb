require "spec_helper"

# Real coverage for WorldBuilder's aggregate-qualified world-binding
# mirror form: `Pizzas::Order.charged_by("Stripe") do ... end`, exactly
# the shape the canonical pizzas.world itself uses to mirror its own
# hecksagon's bind line. Before this fix, WorldBuilder had no ConstShim
# resolver at all (unlike HecksagonBuilder/BluebookBuilder, which both
# already wrap their block eval in one) -- so `Pizzas` failed to
# resolve as a constant during a `.world` block's instance_eval,
# raising `NameError: uninitialized constant Pizzas` for EVERY world
# file using this form, canonical example included. Found live via
# miette's voice.world (`Voice::Voice.voiced_by("ElevenLabs") do ...
# end`).
#
# IR::World#for_verb/#for_binding key purely by verb and adapter name
# -- the aggregate qualifier is NEVER read back out, it exists only so
# a .world file visually mirrors its .hecksagon sibling. So the fix
# writes into the SAME @settings path the bare top-level form already
# uses.
RSpec.describe "WorldBuilder aggregate-qualified binding mirror form" do
  def in_registry
    registry = Hecksagain::Runtime::Registry.new
    Hecks.with_registry(registry) do
      Kernel.load(InMemoryDomain::EXTRACTION_PORT)
      Kernel.load(InMemoryDomain::PRISM_ADAPTER)
      yield
    end
    registry
  end

  it "Domain::Aggregate.verb(...) resolves without raising NameError, exactly the pizzas.world shape" do
    registry = in_registry do
      Hecks.world("WorldMirrorGrowth") do
        realm "Acme"
        latest "v1"

        WorldMirrorGrowth::Order.charged_by("Stripe") do
          api_key "sk_test"
        end
      end
    end

    world = registry.world("WorldMirrorGrowth")
    expect(world.to_h[:realm]).to eq("Acme")
  end

  it "writes into the SAME @settings path as the bare top-level verb form -- for_binding finds it" do
    registry = in_registry do
      Hecks.world("WorldMirrorBindingGrowth") do
        realm "Acme"
        latest "v1"

        WorldMirrorBindingGrowth::Order.charged_by("Stripe") do
          api_key "sk_test"
        end
      end
    end

    world = registry.world("WorldMirrorBindingGrowth")
    settings = world.for_binding("charged_by", "Stripe")
    expect(settings[:adapter]).to eq("Stripe")
    expect(settings[:api_key]).to eq("sk_test")
  end

  it "the bare top-level form and the aggregate-qualified mirror form are interchangeable spellings" do
    top_level_registry = in_registry do
      Hecks.world("WorldMirrorBareGrowth") do
        realm "Acme"
        latest "v1"
        charged_by("Stripe") { api_key "sk_test" }
      end
    end

    mirror_registry = in_registry do
      Hecks.world("WorldMirrorQualifiedGrowth") do
        realm "Acme"
        latest "v1"
        WorldMirrorQualifiedGrowth::Order.charged_by("Stripe") { api_key "sk_test" }
      end
    end

    bare = top_level_registry.world("WorldMirrorBareGrowth").for_binding("charged_by", "Stripe")
    qualified = mirror_registry.world("WorldMirrorQualifiedGrowth").for_binding("charged_by", "Stripe")
    expect(qualified).to eq(bare)
  end
end
