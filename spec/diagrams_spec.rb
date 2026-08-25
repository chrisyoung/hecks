require "spec_helper"

# docs/generated/diagrams/pizzas/ is GENERATED from Pizzas' own declared
# lifecycles by bin/project_diagrams (see Projections::Diagrams's own
# header for why Mermaid, and why lifecycles-only for now) — this spec
# regenerates it into memory and asserts byte equality with the
# committed files, the same drift-detection shape
# spec/parser_table_spec.rb already holds rust/parser/src/keywords.rs to.
RSpec.describe "the generated lifecycle diagrams" do
  let(:committed_dir) { File.expand_path("../docs/generated/diagrams/pizzas", __dir__) }
  let(:chapter) { boot_in_memory.registry.bluebook("Pizzas") }
  let(:order) { chapter.aggregates.find { |a| a.hecks_name == "Order" } }

  it "is exactly what bin/project_diagrams would regenerate from Pizzas' own declared lifecycles right now" do
    regenerated = Hecks::Projector.call(:diagrams, bluebook: chapter)
    expect(regenerated).not_to be_empty

    regenerated.each do |relative, contents|
      path = File.join(committed_dir, relative)
      expect(File).to exist(path), "#{relative} is missing — run bin/project_diagrams examples/pizzas Pizzas"
      expect(File.read(path)).to eq(contents),
                                 "#{relative} is stale — run bin/project_diagrams examples/pizzas Pizzas and commit the result"
    end

    expect(Dir.children(committed_dir).sort).to eq(regenerated.keys.sort),
                                                "docs/generated/diagrams/pizzas/ holds a file the projection no longer " \
                                                "generates — run bin/project_diagrams examples/pizzas Pizzas and remove what's stale"
  end

  # THE CHECK A SILENT DRIFT WOULD MOST LIKELY SLIP PAST: the byte-equality
  # test above only fails once someone forgets to regenerate — this fails
  # the moment the RENDER LOGIC ITSELF miscounts, independent of whether
  # the committed file happens to already be stale in the same way.
  it "draws exactly the edges Order's own lifecycle declares, no more and no fewer" do
    diagram = Hecks::Projector.call(:diagrams, bluebook: chapter)["Order_lifecycle.mmd"]
    lifecycle = order.lifecycle

    declared_edges = lifecycle.transitions.flat_map do |command, transition|
      Array(transition.from).map { |from| "#{from} --> #{transition.target}: #{command}" }
    end
    drawn_edges = diagram.lines.map(&:strip).select { |line| line.include?("-->") && !line.start_with?("[*]") }

    expect(drawn_edges.size).to eq(declared_edges.size)
    declared_edges.each { |edge| expect(drawn_edges).to include(edge) }
  end

  it "starts at the lifecycle's own declared default state" do
    diagram = Hecks::Projector.call(:diagrams, bluebook: chapter)["Order_lifecycle.mmd"]
    expect(diagram).to include("[*] --> #{order.lifecycle.default}")
  end

  # A STRUCTURAL CHECK, NOT A MERMAID PARSE — this repo's own suite takes
  # no Node/npm dependency for that. The generated output here WAS run
  # through the real mermaid.parse() engine once, by hand, to confirm
  # this exact shape is valid Mermaid (this session's own verification,
  # against both a hand-written sample and this real generated file) —
  # this just guards the one structural fact that made that true: the
  # diagram type declaration is the first non-comment line.
  it "is shaped like real Mermaid — the diagram type declared before anything else" do
    diagram = Hecks::Projector.call(:diagrams, bluebook: chapter)["Order_lifecycle.mmd"]
    lines = diagram.lines.map(&:strip).reject(&:empty?)
    first_real_line = lines.find { |line| !line.start_with?("%%") }
    expect(first_real_line).to eq("stateDiagram-v2")
  end
end
