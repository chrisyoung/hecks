require "spec_helper"
require "hecks/runtime/attachment_store"

RSpec.describe Hecks::Runtime::MemoryAttachmentStore do
  subject(:store) { described_class.new }

  describe "#store" do
    it "stores metadata and returns entry with ref_id" do
      entry = store.store("agg-1", :avatar, { filename: "photo.jpg" })

      expect(entry[:filename]).to eq("photo.jpg")
      expect(entry[:ref_id]).to be_a(String)
      expect(entry[:ref_id].length).to eq(36) # UUID
    end

    it "stores multiple attachments for the same attribute" do
      store.store("agg-1", :avatar, { filename: "a.jpg" })
      store.store("agg-1", :avatar, { filename: "b.jpg" })

      expect(store.list("agg-1", :avatar).size).to eq(2)
    end
  end

  describe "#list" do
    it "returns empty array when no attachments exist" do
      expect(store.list("agg-1", :avatar)).to eq([])
    end

    it "returns stored entries for the attribute" do
      store.store("agg-1", :avatar, { filename: "photo.jpg" })
      entries = store.list("agg-1", :avatar)

      expect(entries.size).to eq(1)
      expect(entries.first[:filename]).to eq("photo.jpg")
    end

    it "isolates by aggregate ID" do
      store.store("agg-1", :avatar, { filename: "a.jpg" })
      store.store("agg-2", :avatar, { filename: "b.jpg" })

      expect(store.list("agg-1", :avatar).size).to eq(1)
      expect(store.list("agg-2", :avatar).size).to eq(1)
    end
  end

  describe "#delete" do
    it "removes the entry by ref_id and returns it" do
      entry = store.store("agg-1", :avatar, { filename: "photo.jpg" })
      deleted = store.delete("agg-1", :avatar, entry[:ref_id])

      expect(deleted[:filename]).to eq("photo.jpg")
      expect(store.list("agg-1", :avatar)).to be_empty
    end

    it "returns nil when ref_id not found" do
      expect(store.delete("agg-1", :avatar, "nonexistent")).to be_nil
    end
  end

  describe "#clear" do
    it "removes all stored data" do
      store.store("agg-1", :avatar, { filename: "photo.jpg" })
      store.clear

      expect(store.list("agg-1", :avatar)).to be_empty
    end
  end
end
