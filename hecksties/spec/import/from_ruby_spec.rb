require "spec_helper"
require "hecks_cli"
require "tmpdir"

RSpec.describe "Import.from_ruby" do
  let(:project_dir) { Dir.mktmpdir }

  after { FileUtils.remove_entry(project_dir) }

  def write_file(relative_path, content)
    full_path = File.join(project_dir, relative_path)
    FileUtils.mkdir_p(File.dirname(full_path))
    File.write(full_path, content)
  end

  it "generates a domain from plain Ruby classes" do
    write_file("order.rb", <<~RUBY)
      class Order
        attr_accessor :total, :status
      end
    RUBY

    dsl = Hecks::Import.from_ruby(project_dir, domain_name: "Shop")
    expect(dsl).to include('Hecks.domain "Shop"')
    expect(dsl).to include('aggregate "Order"')
    expect(dsl).to include("attribute :total, String")
    expect(dsl).to include("attribute :status, String")
  end

  it "generates a domain from Struct-based classes" do
    write_file("point.rb", <<~RUBY)
      class Point < Struct.new(:x, :y)
      end
    RUBY

    dsl = Hecks::Import.from_ruby(project_dir, domain_name: "Geometry")
    expect(dsl).to include('aggregate "Point"')
    expect(dsl).to include("attribute :x, String")
  end

  it "groups module-nested classes into aggregates" do
    write_file("billing.rb", <<~RUBY)
      module Billing
        class Invoice
          attr_accessor :total
        end

        class LineItem
          attr_accessor :description
        end
      end
    RUBY

    dsl = Hecks::Import.from_ruby(project_dir, domain_name: "Acme")
    expect(dsl).to include('aggregate "Billing"')
    expect(dsl).to include("attribute :total, String")
    expect(dsl).to include('value_object "LineItem"')
  end

  describe "from_directory auto-detection" do
    it "uses from_ruby for non-Rails projects" do
      write_file("lib/widget.rb", <<~RUBY)
        class Widget
          attr_accessor :name
        end
      RUBY

      dsl = Hecks::Import.from_directory(project_dir, domain_name: "Factory")
      expect(dsl).to include('aggregate "Widget"')
    end

    it "detects Rails projects by schema.rb presence" do
      expect(Hecks::Import.rails_project?(project_dir)).to be false

      FileUtils.mkdir_p(File.join(project_dir, "db"))
      File.write(File.join(project_dir, "db", "schema.rb"), "")
      expect(Hecks::Import.rails_project?(project_dir)).to be true
    end
  end
end
