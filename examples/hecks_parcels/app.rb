#!/usr/bin/env ruby
#
# Example: Land subdivision yield analysis with Hecks
#
# Run from the hecks project root:
#   ruby -Ilib examples/hecks_parcels/app.rb

require "hecks"

app = Hecks.boot(__dir__)

# Listen for domain events
app.on("CreatedProject") { |e| puts "  [event] CreatedProject: #{e.name}" }
app.on("CreatedRoad")    { |e| puts "  [event] CreatedRoad" }
app.on("GeneratedParcel") { |e| puts "  [event] GeneratedParcel: #{e.name}" }
app.on("CreatedNetArea") { |e| puts "  [event] CreatedNetArea: #{e.name}" }

puts "--- Creating a project ---"
project = Project.create(name: "Oakwood Estates")

puts "\n--- Setting boundary (property perimeter) ---"
Project.set_boundary(
  project_id: project.id,
  boundary: [
    { x: 0.0, y: 0.0 },
    { x: 1000.0, y: 0.0 },
    { x: 1000.0, y: 800.0 },
    { x: 0.0, y: 800.0 }
  ]
)

puts "\n--- Drawing roads ---"
collector = Road.create(
  project_id: project.id,
  name: "Main Street",
  points: [
    { x: 0.0, y: 400.0 },
    { x: 1000.0, y: 400.0 }
  ]
)
puts "Road: #{collector.name} (#{collector.road_type}, ROW: #{collector.row_width}ft)"

arterial = Road.create(
  project_id: project.id,
  name: "Oak Boulevard",
  points: [
    { x: 500.0, y: 0.0 },
    { x: 500.0, y: 800.0 }
  ]
)

Road.update_road_props(
  road_id: arterial.id,
  name: "Oak Boulevard",
  road_type: "arterial",
  row_width: 120.0,
  show_setbacks: true,
  setback_distance: 25.0
)

puts "\n--- Adding parcel lines ---"
ParcelLine.create(
  project_id: project.id,
  points: [{ x: 250.0, y: 0.0 }, { x: 250.0, y: 400.0 }]
)

puts "\n--- Generating parcels ---"
parcel_a = Parcel.generate(
  project_id: project.id,
  name: "A",
  points: [
    { x: 0.0, y: 0.0 }, { x: 250.0, y: 0.0 },
    { x: 250.0, y: 400.0 }, { x: 0.0, y: 400.0 }
  ],
  area: 100_000.0
)

parcel_b = Parcel.generate(
  project_id: project.id,
  name: "B",
  points: [
    { x: 250.0, y: 0.0 }, { x: 500.0, y: 0.0 },
    { x: 500.0, y: 400.0 }, { x: 250.0, y: 400.0 }
  ],
  area: 100_000.0
)

parcel_c = Parcel.generate(
  project_id: project.id,
  name: "C",
  points: [
    { x: 500.0, y: 0.0 }, { x: 1000.0, y: 0.0 },
    { x: 1000.0, y: 400.0 }, { x: 500.0, y: 400.0 }
  ],
  area: 200_000.0
)

park = Parcel.generate(
  project_id: project.id,
  name: "Park",
  points: [
    { x: 0.0, y: 400.0 }, { x: 1000.0, y: 400.0 },
    { x: 1000.0, y: 800.0 }, { x: 0.0, y: 800.0 }
  ],
  area: 400_000.0
)

puts "\n--- Configuring parcel properties ---"
Parcel.update_parcel_props(
  parcel_id: parcel_a.id, name: "A", density: 3.1,
  is_residential: true, avg_lot_size: "60x120"
)

Parcel.update_parcel_props(
  parcel_id: parcel_b.id, name: "B", density: 5.2,
  is_residential: true, avg_lot_size: "50x90"
)

Parcel.update_parcel_props(
  parcel_id: parcel_c.id, name: "C", density: 4.0,
  is_residential: true, avg_lot_size: "55x110"
)

Parcel.update_parcel_props(
  parcel_id: park.id, name: "Central Park",
  is_residential: false, use_type: "park"
)

puts "\n--- Adding a net area (pond deduction) ---"
NetArea.create(
  project_id: project.id,
  name: "Retention Pond",
  points: [
    { x: 600.0, y: 100.0 }, { x: 700.0, y: 100.0 },
    { x: 700.0, y: 200.0 }, { x: 600.0, y: 200.0 }
  ]
)

puts "\n--- Lot yield report ---"
residential = Parcel.residential
puts "Residential parcels: #{residential.count}"
residential.each do |p|
  acres = (p.area / 43_560.0).round(2)
  lots = (acres * p.density).floor
  puts "  #{p.name}: #{acres} acres, density #{p.density}/ac = #{lots} lots (#{p.avg_lot_size})"
end

puts "\n--- All parcels ---"
Parcel.all.each do |p|
  label = p.is_residential ? "residential" : p.use_type
  puts "  #{p.name}: #{label}"
end

puts "\n--- Roads ---"
Road.all.each do |r|
  puts "  #{r.name}: #{r.road_type} (ROW #{r.row_width}ft)"
end

puts "\n--- Net areas ---"
NetArea.all.each do |na|
  puts "  #{na.name} (locked: #{na.locked})"
end

puts "\n--- Event history ---"
app.events.each_with_index do |event, i|
  name = event.class.name.split("::").last
  puts "  #{i + 1}. #{name} at #{event.occurred_at}"
end

# Wiring: HecksParcels
#   command_bus
#     http: REST and JSON-RPC server with OpenAPI docs
#     auth: Actor-based authorization via port guards
#   domain
#     mcp: MCP server for AI-assisted domain modeling
#   event_bus
#     audit: Immutable audit trail for every domain event
#     sockets: WebSocket server for live domain events and commands
#   repository
#     pii: PII field encryption and masking

Hecks.configure do
  domain "hecks_parcels_domain"
  adapter :memory

  # Detect and enable all available extensions.
  # Comment out to disable auto-wiring and use explicit extensions below.
  auto_wire

  # Or pick exactly what you want:
  # auto_wire except: [:pii]
  # auto_wire only: [:http, :sockets, :audit]

  # Override individual extension options:
  # extension :http, port: 9292, rpc: false
  # extension :mcp, port: 8080
  # extension :auth
  # extension :audit
  # extension :pii
  # extension :sockets, port: 9293

end
