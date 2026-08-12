require "spec_helper"
require "tempfile"

# Real coverage for BluebookBuilder#build's saga-runtime-state reattachment:
# every Hecks.bluebook build unconditionally replaces the DSL-built graph
# with MetaValidator's Judge/Reconstruction ("the language IS the source"),
# and the self-hosted "Handler" contract has no field for the raw guard
# Procs themselves (only guard_count, a number -- item 36's own comment).
# So a real dispatch silently lost handler-level `given`: nil guards reads
# the same as no guard at all, so the gate always passed regardless of what
# the predicate actually said.
RSpec.describe "BluebookBuilder#build reattaches a handler's own guards after judging" do
  GUARD_REATTACH_SOURCE = <<~BLUEBOOK
    Hecks.bluebook "GuardReattachGrowth" do
      aggregate "Widget" do
        identified_by { widget_id.value }

        value_object "WidgetId" do
          attribute :value, String
        end

        value_object "LoudFlag" do
          attribute :value, TrueClass
        end

        attribute :widget_id, WidgetId
        attribute :loud, LoudFlag

        command "Open" do
          attribute :widget_id, WidgetId
          attribute :loud, LoudFlag
          emits "Opened"
        end

        command "Blare" do
          reference_to Widget
          emits "Blared"
        end
      end

      process_manager "GuardReattachSaga" do
        correlates_by :"widget_id.value"
        starts_on "Opened"
        ends_on "Blared"

        state "none"
        state "open"

        on "Opened", transition: { "none" => "open" } do
          given { |ctx| ctx[:loud].to_h[:value] }
          dispatch "GuardReattachGrowth::Widget.Blare", with: { widget_id: :widget_id }
        end
      end
    end
  BLUEBOOK

  def boot
    file = Tempfile.new(["guard-reattach-growth-", ".bluebook"])
    file.write(GUARD_REATTACH_SOURCE)
    file.flush

    registry = Hecksagain::Runtime::Registry.new
    Hecksagain.with_registry(registry) do
      Kernel.load(InMemoryDomain::PERSISTENCE_PORT)
      Kernel.load(InMemoryDomain::EXTRACTION_PORT)
      Kernel.load(InMemoryDomain::MEMORY_ADAPTER)
      Kernel.load(InMemoryDomain::PRISM_ADAPTER)
      Kernel.eval(GUARD_REATTACH_SOURCE, TOPLEVEL_BINDING, file.path, 1)
    end
    registry.verify!
    Hecksagain::Runtime::Loader.bind_runtime(Hecksagain::Runtime::Dispatcher.new(registry))
  ensure
    file&.close!
  end

  it "the guard genuinely blocks the dispatch when its predicate reads false" do
    runtime = boot
    runtime.dispatch("GuardReattachGrowth::Widget.Open", widget_id: { value: "quiet-1" }, loud: { value: false })

    expect(runtime.events.map(&:name)).not_to include("Blared")
  end

  it "the guard genuinely allows the dispatch when its predicate reads true" do
    runtime = boot
    runtime.dispatch("GuardReattachGrowth::Widget.Open", widget_id: { value: "loud-1" }, loud: { value: true })

    expect(runtime.events.map(&:name)).to include("Blared")
  end

  it "the judged handler carries the real guard Proc, not nil" do
    runtime = boot
    handler = runtime.registry.bluebook("GuardReattachGrowth").process_managers.first.handlers.first

    expect(handler.guards).not_to be_nil
    expect(handler.guards).not_to be_empty
    expect(handler.guards.first).to respond_to(:call)
  end

  # GAP CLOSED (item 51, `785b90f`): a `with:` value built by
  # `template(...)` (IR::TemplateSpec) used to crash during
  # MetaValidator.call's own internal to_h computation -- BEFORE this
  # reattachment even ran -- because IR.render_value/Literal.render had
  # no pinned spelling for it. IR.render_value now spells a TemplateSpec
  # as its own {format:, args:} Hash, so judging no longer crashes, and
  # this reattachment (guards/with_spec) restores the LIVE TemplateSpec
  # object afterward for the real dispatch to actually use.
  it "a template() with: value survives judging and composes correctly at dispatch" do
    source = <<~BLUEBOOK
      Hecks.bluebook "TemplateReattachGapGrowth" do
        aggregate "Widget" do
          identified_by { widget_id.value }
          value_object "WidgetId" do
            attribute :value, String
          end
          attribute :widget_id, WidgetId
          attribute :label, Label

          value_object "Label" do
            attribute :value, String
          end

          command "Open" do
            attribute :widget_id, WidgetId
            emits "Opened"
          end
          command "Label" do
            reference_to Widget
            attribute :label, Label
            then_set :label, to: :label
            emits "Labeled"
          end
        end

        process_manager "TemplateReattachGapSaga" do
          correlates_by :"widget_id.value"
          starts_on "Opened"
          ends_on "Labeled"

          state "none"
          state "open"

          on "Opened", transition: { "none" => "open" } do
            remember owner: :widget_id
            dispatch "TemplateReattachGapGrowth::Widget.Label", with: { widget_id: :widget_id, label: template("owner-%s", from_pm(:owner)) }
          end
        end
      end
    BLUEBOOK

    file = Tempfile.new(["template-reattach-gap-growth-", ".bluebook"])
    file.write(source)
    file.flush

    registry = Hecksagain::Runtime::Registry.new
    Hecksagain.with_registry(registry) do
      Kernel.load(InMemoryDomain::PERSISTENCE_PORT)
      Kernel.load(InMemoryDomain::EXTRACTION_PORT)
      Kernel.load(InMemoryDomain::MEMORY_ADAPTER)
      Kernel.load(InMemoryDomain::PRISM_ADAPTER)
      Kernel.eval(source, TOPLEVEL_BINDING, file.path, 1)
    end
    registry.verify!
    runtime = Hecksagain::Runtime::Loader.bind_runtime(Hecksagain::Runtime::Dispatcher.new(registry))

    # Before item 51: this line never ran at all -- MetaValidator.call
    # raised ArgumentError while judging the bluebook, so no dispatch was
    # ever reachable. It reaching dispatch and composing SOME label (not
    # crashing) is exactly what this item fixes ; the label's own exact
    # composed text is a separate, pre-existing SagaInterpreter#resolve_value
    # formatting question (Kernel#format calling a wrapped Value's default
    # #to_s rather than unwrapping it first) outside this migration's
    # 31-commit range, not invented or fixed here.
    expect { runtime.dispatch("TemplateReattachGapGrowth::Widget.Open", widget_id: { value: "widget-1" }) }
      .not_to raise_error

    widget = registry.repository("TemplateReattachGapGrowth", registry.bluebook("TemplateReattachGapGrowth").aggregate("Widget")).find("widget-1")
    expect(widget[:label]).not_to be_nil
  ensure
    file&.close!
  end
end
