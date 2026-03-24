require "benchmark"
require_relative "../lib/hecks"

# Build a domain with enough structure to exercise the full path
domain = Hecks.domain "Bench" do
  aggregate "Widget" do
    attribute :name, String
    attribute :style, String
    attribute :price, Float
    attribute :tags, list_of("Tag")

    value_object "Tag" do
      attribute :label, String
    end

    command "CreateWidget" do
      attribute :name, String
      attribute :style, String
      attribute :price, Float
    end

    command "UpdateWidget" do
      attribute :name, String
      attribute :style, String
      attribute :price, Float
    end

    query "ByStyle" do |style|
      where(style: style)
    end

    query "Expensive" do
      where(price: gt(20.0))
    end
  end
end

Hecks.load_domain(domain, force: true)
app = Hecks::Application.new(domain)

puts "=== Hecks Performance Benchmarks ==="
puts

# --- Command Dispatch ---
puts "--- Command Dispatch ---"
puts

Benchmark.bm(30) do |x|
  x.report("1 create") do
    BenchDomain::Widget.create(name: "W", style: "A", price: 10.0)
  end

  x.report("100 creates") do
    100.times { |i| BenchDomain::Widget.create(name: "W#{i}", style: "A", price: 10.0) }
  end

  x.report("1,000 creates") do
    1_000.times { |i| BenchDomain::Widget.create(name: "W#{i}", style: "A", price: 10.0) }
  end

  x.report("10,000 creates") do
    10_000.times { |i| BenchDomain::Widget.create(name: "W#{i}", style: "A", price: 10.0) }
  end
end

puts
puts "--- Query Performance (memory adapter) ---"
puts

# Seed data — enable ad-hoc queries for where/order/limit
app2 = Hecks::Application.new(domain)
domain.aggregates.each do |agg|
  agg_class = BenchDomain.const_get(agg.name)
  Hecks::Querying::AdHocQueries.bind(agg_class, app2[agg.name])
end
styles = %w[Classic Modern Retro Minimal Bold]
10_000.times do |i|
  BenchDomain::Widget.create(
    name: "Widget#{i}",
    style: styles[i % styles.length],
    price: (i % 50) + 1.0
  )
end
repo = app2["Widget"]
puts "Seeded #{repo.count} widgets"
puts

Benchmark.bm(30) do |x|
  x.report("all (10k)") { repo.all }

  x.report("where (style)") do
    BenchDomain::Widget.by_style("Classic")
  end

  x.report("where + order") do
    BenchDomain::Widget.where(style: "Modern").order(:name).to_a
  end

  x.report("where + order + limit(10)") do
    BenchDomain::Widget.where(style: "Retro").order(:price).limit(10).to_a
  end

  x.report("where with gt") do
    BenchDomain::Widget.expensive.to_a
  end

  x.report("find by id") do
    id = repo.all.first.id
    repo.find(id)
  end

  x.report("100x find by id") do
    ids = repo.all.first(100).map(&:id)
    ids.each { |id| repo.find(id) }
  end

  x.report("count") { repo.count }
end

puts
puts "--- Scaling: query over growing dataset ---"
puts

[100, 1_000, 5_000, 10_000].each do |n|
  app_n = Hecks::Application.new(domain)
  domain.aggregates.each do |agg|
    agg_class = BenchDomain.const_get(agg.name)
    Hecks::Querying::AdHocQueries.bind(agg_class, app_n[agg.name])
  end
  n.times { |i| BenchDomain::Widget.create(name: "W#{i}", style: styles[i % 5], price: (i % 50) + 1.0) }

  time = Benchmark.realtime do
    100.times { BenchDomain::Widget.where(style: "Classic").order(:name).limit(10).to_a }
  end
  puts "  #{n.to_s.rjust(6)} widgets: 100x where+order+limit => #{(time * 1000).round(1)}ms total (#{(time * 10).round(2)}ms/query)"
end
