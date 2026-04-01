require "spec_helper"

RSpec.describe "Hecks::Conventions::Names FQN builders" do
  let(:names) { Hecks::Conventions::Names }

  describe ".domain_command_fqn" do
    it "builds fully-qualified command class name" do
      expect(names.domain_command_fqn("CatsDomain", "Cat", "Adopt"))
        .to eq("CatsDomain::Cat::Commands::Adopt")
    end
  end

  describe ".domain_event_fqn" do
    it "builds fully-qualified event class name" do
      expect(names.domain_event_fqn("CatsDomain", "Cat", "AdoptedCat"))
        .to eq("CatsDomain::Cat::Events::AdoptedCat")
    end
  end

  describe ".domain_policy_fqn" do
    it "builds fully-qualified policy class name" do
      expect(names.domain_policy_fqn("CatsDomain", "Cat", "CanAdopt"))
        .to eq("CatsDomain::Cat::Policies::CanAdopt")
    end
  end

  describe ".actor_roles_for" do
    it "builds actor map from domain aggregates" do
      actor = double(:actor, name: "Admin")
      cmd_with_actor = double(:command, name: "Adopt", actors: [actor])
      cmd_without_actor = double(:command, name: "Feed", actors: [])
      agg = double(:aggregate, name: "Cat", commands: [cmd_with_actor, cmd_without_actor])
      domain = double(:domain, aggregates: [agg])
      domain_mod = double(:domain_mod, name: "CatsDomain")

      result = names.actor_roles_for(domain, domain_mod)

      expect(result).to eq("CatsDomain::Cat::Commands::Adopt" => ["Admin"])
      expect(result).not_to have_key("CatsDomain::Cat::Commands::Feed")
    end

    it "returns empty hash when no actors declared" do
      cmd = double(:command, name: "Feed", actors: [])
      agg = double(:aggregate, name: "Cat", commands: [cmd])
      domain = double(:domain, aggregates: [agg])
      domain_mod = double(:domain_mod, name: "CatsDomain")

      expect(names.actor_roles_for(domain, domain_mod)).to eq({})
    end
  end
end
