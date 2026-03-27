#!/usr/bin/env ruby
#
# Seed data for AI Governance Platform.
# Run after boot: load 'seeds.rb'
#
require "date"

puts "--- Seeding regulatory frameworks ---"
eu_ai = RegulatoryFramework.register(name: "EU AI Act", jurisdiction: "EU", version: "2024", authority: "European Commission")
RegulatoryFramework.activate(framework_id: eu_ai.id, effective_date: Date.new(2026, 8, 1))

nist = RegulatoryFramework.register(name: "NIST AI RMF", jurisdiction: "US", version: "1.0", authority: "NIST")
RegulatoryFramework.activate(framework_id: nist.id, effective_date: Date.new(2023, 1, 26))

iso = RegulatoryFramework.register(name: "ISO 42001", jurisdiction: "International", version: "2023", authority: "ISO")
RegulatoryFramework.activate(framework_id: iso.id, effective_date: Date.new(2023, 12, 18))
puts "Frameworks: #{RegulatoryFramework.count}"

puts "--- Seeding governance policies ---"
[
  { name: "High-Risk AI Systems", category: "regulatory", framework: eu_ai },
  { name: "Bias and Fairness", category: "ethical", framework: eu_ai },
  { name: "Transparency Requirements", category: "regulatory", framework: eu_ai },
  { name: "Data Governance", category: "operational", framework: nist },
  { name: "Risk Management", category: "internal", framework: iso },
].each do |p|
  policy = GovernancePolicy.create(name: p[:name], description: "#{p[:name]} policy", category: p[:category], framework_id: p[:framework].id)
  GovernancePolicy.activate(policy_id: policy.id, effective_date: Date.today)
end
puts "Policies: #{GovernancePolicy.count}"

puts "--- Seeding stakeholder roles ---"
[
  { name: "Admin User", email: "admin@governance.ai", role: "admin", team: "platform" },
  { name: "Risk Assessor", email: "assessor@governance.ai", role: "assessor", team: "risk" },
  { name: "Compliance Reviewer", email: "reviewer@governance.ai", role: "reviewer", team: "compliance" },
  { name: "Board Member", email: "board@governance.ai", role: "governance_board", team: "leadership" },
  { name: "Data Steward", email: "data@governance.ai", role: "data_steward", team: "data" },
].each do |s|
  Stakeholder.register(**s)
end
puts "Stakeholders: #{Stakeholder.count}"

puts "--- Seed complete ---"
