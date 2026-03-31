require "spec_helper"
require "tmpdir"

RSpec.describe "Demo Script Verification" do
  before { allow($stdout).to receive(:puts) }

  describe "Act 1: Sketch & Play" do
    describe "sketch mode" do
      let(:workshop) { Hecks::Workshop.new("BlogSketch") }

      it "builds Post with attributes, lifecycle, transitions, and commands" do
        post = workshop.aggregate("Post")
        post.attr :title, String
        post.attr :status, String
        post.lifecycle :status, default: "draft"
        post.transition "PublishPost" => "published"
        post.transition "ArchivePost" => "archived"
        post.command("CreatePost") { attribute :title, String }

        domain = workshop.to_domain
        agg = domain.aggregates.find { |a| a.name == "Post" }
        expect(agg.attributes.map(&:name)).to include(:title, :status)
        expect(agg.commands.map(&:name)).to include("CreatePost")
        expect(agg.lifecycle.transitions).to eq("PublishPost" => "published", "ArchivePost" => "archived")
        expect(agg.lifecycle.default).to eq("draft")
      end

      it "builds Comment with reference and commands" do
        workshop.aggregate("Post").attr :title, String
        comment = workshop.aggregate("Comment")
        comment.reference_to("Post")
        comment.attr :author, String
        comment.attr :body, String
        comment.command("CreateComment") do
          reference_to "Post"
          attribute :author, String
          attribute :body, String
        end

        domain = workshop.to_domain
        agg = domain.aggregates.find { |a| a.name == "Comment" }
        expect(agg.references.find { |r| r.type == "Post" }).not_to be_nil
        expect(agg.commands.map(&:name)).to include("CreateComment")
      end

      it "exports domain to file" do
        Dir.mktmpdir do |dir|
          post = workshop.aggregate("Post")
          post.attr :title, String
          post.command("CreatePost") { attribute :title, String }

          path = File.join(dir, "PizzasBluebook")
          workshop.save(path)
          expect(File.exist?(path)).to be true
          content = File.read(path)
          expect(content).to include('Hecks.domain "BlogSketch"')
          expect(content).to include("Post")
        end
      end
    end

    describe "play mode" do
      it "enters play mode and executes commands" do
        wb = Hecks::Workshop.new("PlayBasic")
        post = wb.aggregate("Post")
        post.attr :title, String
        post.command("CreatePost") { attribute :title, String }

        wb.play!
        mod = Object.const_get("PlayBasicDomain")
        created = mod::Post.create(title: "Hello World")
        expect(created.title).to eq("Hello World")
      end

      it "lifecycle sets default status on create" do
        wb = Hecks::Workshop.new("PlayDefault")
        post = wb.aggregate("Post")
        post.attr :title, String
        post.attr :status, String
        post.lifecycle :status, default: "draft"
        post.transition "PublishPost" => "published"
        post.command("CreatePost") { attribute :title, String }

        wb.play!
        mod = Object.const_get("PlayDefaultDomain")
        created = mod::Post.create(title: "Hello World")
        expect(created.status).to eq("draft")
      end

      it "publishes a post via lifecycle transition" do
        wb = Hecks::Workshop.new("PlayTransition")
        post = wb.aggregate("Post")
        post.attr :title, String
        post.attr :status, String
        post.lifecycle :status, default: "draft"
        post.transition "PublishPost" => "published"
        post.command("CreatePost") { attribute :title, String }

        wb.play!
        mod = Object.const_get("PlayTransitionDomain")
        created = mod::Post.create(title: "Hello World")
        published = mod::Post.publish(post: created.id)
        expect(published.status).to eq("published")
      end

      it "captures events" do
        wb = Hecks::Workshop.new("PlayEvents")
        post = wb.aggregate("Post")
        post.attr :title, String
        post.command("CreatePost") { attribute :title, String }

        wb.play!
        mod = Object.const_get("PlayEventsDomain")
        mod::Post.create(title: "Test")
        expect(wb.events.size).to eq(1)
      end
    end
  end

  describe "Act 3: Multi-domain" do
    it "promotes an aggregate into a standalone domain" do
      Dir.mktmpdir do |dir|
        domain = Hecks.domain("Blog") do
          aggregate "Post" do
            attribute :title, String
            command "CreatePost" do
              attribute :title, String
            end
          end
          aggregate "Comment" do
            attribute :body, String
            command "CreateComment" do
              attribute :body, String
            end
          end
        end

        agg = domain.aggregates.find { |a| a.name == "Comment" }
        new_domain = Hecks::DomainModel::Structure::Domain.new(
          name: "Comment", aggregates: [agg], custom_verbs: []
        )
        new_file = File.join(dir, "comment_domain.rb")
        File.write(new_file, Hecks::DslSerializer.new(new_domain).serialize)

        remaining = domain.aggregates.reject { |a| a.name == "Comment" }
        updated = Hecks::DomainModel::Structure::Domain.new(
          name: domain.name, aggregates: remaining, custom_verbs: []
        )

        expect(File.exist?(new_file)).to be true
        expect(File.read(new_file)).to include('Hecks.domain "Comment"')
        expect(updated.aggregates.map(&:name)).to eq(["Post"])
      end
    end
  end

  describe "Act 4: Extend" do
    it "registers extensions without error" do
      wb = Hecks::Workshop.new("ExtendDemo")
      post = wb.aggregate("Post")
      post.attr :title, String
      post.command("CreatePost") { attribute :title, String }
      wb.play!

      mod = Object.const_get("ExtendDemoDomain")
      expect(mod).to be_a(Module)

      %i[tenancy audit].each do |ext|
        expect { wb.extend(ext) }.not_to raise_error
      end
    end
  end

  describe "Act 5: Diff" do
    it "detects added aggregates" do
      old_domain = Hecks.domain("DiffA") do
        aggregate "Post" do
          attribute :title, String
        end
      end

      new_domain = Hecks.domain("DiffA") do
        aggregate "Post" do
          attribute :title, String
        end
        aggregate "Comment" do
          attribute :body, String
        end
      end

      changes = Hecks::Migrations::DomainDiff.call(old_domain, new_domain)
      added = changes.select { |c| c.kind == :add_aggregate }
      expect(added.map(&:aggregate)).to include("Comment")
    end

    it "detects removed attributes as breaking changes" do
      old_domain = Hecks.domain("DiffB") do
        aggregate "Post" do
          attribute :title, String
          attribute :body, String
        end
      end

      new_domain = Hecks.domain("DiffB") do
        aggregate "Post" do
          attribute :title, String
        end
      end

      changes = Hecks::Migrations::DomainDiff.call(old_domain, new_domain)
      removed = changes.select { |c| c.kind == :remove_attribute }
      expect(removed).not_to be_empty
    end
  end

  describe "Act 7: Rails" do
    it "generates a Rails app with Gemfile and initializer" do
      Dir.mktmpdir do |dir|
        domain = Hecks.domain("Blog") do
          aggregate "Post" do
            attribute :title, String
            command "CreatePost" do
              attribute :title, String
            end
          end
        end

        require "hecks/generators/rails_generator"
        generator = Hecks::Generators::RailsGenerator.new(domain)
        allow(generator).to receive(:system).and_return(true)

        app_root = File.join(dir, "blog_rails")
        FileUtils.mkdir_p(app_root)
        File.write(File.join(app_root, "Gemfile"), "source \"https://rubygems.org\"\ngem \"rails\"\n")

        result = generator.generate(output_dir: dir)
        expect(result).to eq(app_root)

        gemfile = File.read(File.join(app_root, "Gemfile"))
        expect(gemfile).to include('gem "hecks"')
        expect(gemfile).to include('gem "blog_domain"')

        init = File.read(File.join(app_root, "config", "initializers", "hecks.rb"))
        expect(init).to include('domain "blog_domain"')
        expect(init).to include("adapter :memory")
      end
    end
  end
end
