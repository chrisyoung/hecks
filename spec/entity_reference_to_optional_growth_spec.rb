require "spec_helper"

# Real coverage for EntityBuilder#reference_to's new `optional:` kwarg —
# the same third argument an aggregate's own `reference_to` already
# takes: a piece free to point at one of several possible targets,
# never more than one at a time. Does NOT register the target in the
# owning aggregate's own `reference_targets` (the bidirectional-
# relationship list `bluebook_builder.rb` builds for docs) — `IR::Entity`
# has no such reader to populate. A real, small, deliberately deferred
# gap; nothing about dispatch, hydration, or querying needs it.
RSpec.describe "EntityBuilder#reference_to optional:" do
  def build_entity(name, &block)
    Hecksagain::Bluebook::DSL::EntityBuilder.build(name) do
      instance_eval(&block) if block
    end
  end

  it "defaults to required (optional: false) exactly as before" do
    entity = build_entity("Card") { reference_to "Team" }

    field = entity.attribute(:team_id)
    expect(field).not_to be_nil
    expect(field.optional?).to be(false)
  end

  it "optional: true marks the reference field optional, same as an aggregate's own reference_to" do
    entity = build_entity("Card") { reference_to "Team", optional: true }

    field = entity.attribute(:team_id)
    expect(field.optional?).to be(true)
  end

  it "optional: still composes with as:" do
    entity = build_entity("Card") { reference_to "Team", as: :assigned_team, optional: true }

    field = entity.attribute(:assigned_team)
    expect(field).not_to be_nil
    expect(field.optional?).to be(true)
  end

  it "the reference field is still a real IR::Reference, unaffected by optional:" do
    entity = build_entity("Card") { reference_to "Team", optional: true }
    field_type = entity.attribute(:team_id).type
    expect(field_type).to be_a(Hecksagain::Bluebook::IR::Reference)
    expect(field_type.target_name).to eq("Team")
  end
end
