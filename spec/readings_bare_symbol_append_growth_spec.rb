require "spec_helper"
require "tempfile"

# Real coverage for MetaValidator::Readings#mutation_rows's own
# bare-symbol append handling: `then_set :list, append: :single_value`
# appends a scalar/single-field-VO value DIRECTLY, rather than a Hash
# of named fields (`append: { field: :src, ... }`). The Judge's own
# mutation-row projection had no "field" to iterate for that shape --
# mirrors `IR::Command::Mutation#appended_fields`'s own already-landed
# vendored fallback (one field named :value).
#
# Exercised WITH real meta-validation ON (no ENV override) -- this is
# specifically the self-hosted grammar's own Judge path, not the
# runtime MutationApplier (which already handled the bare-symbol shape
# before this fix).
RSpec.describe "MetaValidator::Readings bare-symbol append" do
  def boot(source, hecksagon_name, &binds)
    file = Tempfile.new(["readings-bare-append-growth-", ".bluebook"])
    file.write(source)
    file.flush

    registry = Hecksagain::Runtime::Registry.new
    Hecksagain.with_registry(registry) do
      Kernel.load(InMemoryDomain::PERSISTENCE_PORT)
      Kernel.load(InMemoryDomain::EXTRACTION_PORT)
      Kernel.load(InMemoryDomain::MEMORY_ADAPTER)
      Kernel.load(InMemoryDomain::PRISM_ADAPTER)
      Kernel.eval(source, TOPLEVEL_BINDING, file.path, 1)
      Hecks.hecksagon(hecksagon_name, &binds)
    end

    registry.verify!
    Hecksagain::Runtime::Loader.bind_runtime(
      Hecksagain::Runtime::Dispatcher.new(registry)
    )
  ensure
    file&.close!
  end

  BARE_APPEND_SOURCE = <<~BLUEBOOK
    Hecks.bluebook "ReadingsBareAppendGrowth" do
      aggregate "Playlist" do
        identified_by { playlist_id.value }

        value_object "PlaylistId" do
          attribute :value, String
        end

        value_object "TrackName" do
          attribute :value, String
        end

        attribute :playlist_id, PlaylistId
        attribute :tracks, list_of(TrackName)

        command "AddTrack" do
          attribute :playlist_id, PlaylistId
          attribute :track, TrackName
          then_set :tracks, append: :track
          emits "TrackAdded"
        end
      end
    end
  BLUEBOOK

  it "boots without a MetaValidator refusal -- the Judge's own mutation-row projection survives a bare-symbol append" do
    expect do
      boot(BARE_APPEND_SOURCE, "ReadingsBareAppendGrowth") do
        ::ReadingsBareAppendGrowth::Playlist.persisted_by("Memory")
      end
    end.not_to raise_error
  end

  it "a real dispatch through the fully-validated bluebook appends the value onto the list" do
    runtime = boot(BARE_APPEND_SOURCE, "ReadingsBareAppendGrowth") do
      ::ReadingsBareAppendGrowth::Playlist.persisted_by("Memory")
    end

    runtime.dispatch("ReadingsBareAppendGrowth::Playlist.AddTrack",
                      playlist_id: { value: "p1" }, track: { value: "Track One" })

    bluebook = runtime.registry.bluebook("ReadingsBareAppendGrowth")
    aggregate = bluebook.aggregate("Playlist")
    record = runtime.registry.repository("ReadingsBareAppendGrowth", aggregate).find("p1")

    expect(record[:tracks].map { |t| t[:value] }).to eq(["Track One"])
  end
end
