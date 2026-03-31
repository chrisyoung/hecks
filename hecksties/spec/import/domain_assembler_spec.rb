require "spec_helper"

RSpec.describe Hecks::Import::DomainAssembler do
  let(:schema_data) do
    [
      {
        name: "posts",
        columns: [
          { name: "title", type: :string },
          { name: "body", type: :text },
          { name: "views", type: :integer },
          { name: "published", type: :boolean },
          { name: "author_id", type: :reference, target: "author" }
        ],
        foreign_keys: ["author_id"]
      },
      {
        name: "authors",
        columns: [
          { name: "name", type: :string },
          { name: "email", type: :string }
        ],
        foreign_keys: []
      }
    ]
  end

  let(:model_data) do
    {
      "Post" => {
        associations: [{ type: :belongs_to, name: "author" }],
        validations: [{ field: "title", rules: { presence: true } }],
        enums: { "status" => %w[draft published archived] },
        state_machine: {
          field: "status", initial: "draft",
          transitions: [
            { event: "publish", from: "draft", to: "published" },
            { event: "archive", from: "published", to: "archived" }
          ]
        }
      }
    }
  end

  subject(:dsl) { described_class.new(schema_data, model_data, domain_name: "Blog").assemble }

  it "generates valid DSL wrapper" do
    expect(dsl).to start_with('Hecks.domain "Blog" do')
    expect(dsl).to end_with("end\n")
  end

  it "generates aggregates from tables" do
    expect(dsl).to include('aggregate "Post" do')
    expect(dsl).to include('aggregate "Author" do')
  end

  it "maps column types to Hecks types" do
    expect(dsl).to include("attribute :title, String")
    expect(dsl).to include("attribute :body, String")
    expect(dsl).to include("attribute :views, Integer")
    expect(dsl).to include("attribute :published, TrueClass")
  end

  it "converts foreign keys to references" do
    expect(dsl).to include('reference_to "Author"')
  end

  it "includes validations from model data" do
    expect(dsl).to include('validation :title, {:presence=>true}')
  end

  it "generates lifecycle from state machine" do
    expect(dsl).to include('lifecycle :status, default: "draft" do')
    expect(dsl).to include('transition "PublishPost" => "published"')
    expect(dsl).to include('transition "ArchivePost" => "archived"')
  end

  it "generates Create commands" do
    expect(dsl).to include('command "CreatePost" do')
    expect(dsl).to include('command "CreateAuthor" do')
  end

  context "without model data" do
    subject(:dsl) { described_class.new(schema_data, {}, domain_name: "Blog").assemble }

    it "still generates valid DSL" do
      expect(dsl).to include('aggregate "Post" do')
      expect(dsl).to include("attribute :title, String")
    end
  end
end
