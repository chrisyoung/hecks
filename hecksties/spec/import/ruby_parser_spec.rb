require "spec_helper"
require "hecks_cli"
require "tmpdir"

RSpec.describe Hecks::Import::RubyParser do
  let(:project_dir) { Dir.mktmpdir }

  after { FileUtils.remove_entry(project_dir) }

  def write_file(relative_path, content)
    full_path = File.join(project_dir, relative_path)
    FileUtils.mkdir_p(File.dirname(full_path))
    File.write(full_path, content)
  end

  subject(:parsed) { described_class.new(project_dir).parse }

  describe "plain Ruby classes (POROs)" do
    before do
      write_file("order.rb", <<~RUBY)
        class Order
          attr_accessor :total, :currency
          attr_reader :status
        end
      RUBY
    end

    it "extracts the class name" do
      expect(parsed.map { |c| c[:name] }).to include("Order")
    end

    it "extracts attr_accessor and attr_reader attributes" do
      order = parsed.find { |c| c[:name] == "Order" }
      names = order[:attributes].map { |a| a[:name] }
      expect(names).to contain_exactly("total", "currency", "status")
    end

    it "defaults attribute types to String" do
      order = parsed.find { |c| c[:name] == "Order" }
      expect(order[:attributes]).to all(include(type: "String"))
    end
  end

  describe "Struct.new subclasses" do
    before do
      write_file("point.rb", <<~RUBY)
        class Point < Struct.new(:x, :y, :z)
        end
      RUBY
    end

    it "extracts Struct members as attributes" do
      point = parsed.find { |c| c[:name] == "Point" }
      names = point[:attributes].map { |a| a[:name] }
      expect(names).to contain_exactly("x", "y", "z")
    end

    it "records Struct as superclass" do
      point = parsed.find { |c| c[:name] == "Point" }
      expect(point[:superclass]).to eq("Struct")
    end
  end

  describe "Data.define subclasses" do
    before do
      write_file("money.rb", <<~RUBY)
        class Money < Data.define(:amount, :currency)
        end
      RUBY
    end

    it "extracts Data members as attributes" do
      money = parsed.find { |c| c[:name] == "Money" }
      names = money[:attributes].map { |a| a[:name] }
      expect(names).to contain_exactly("amount", "currency")
    end

    it "records Data as superclass" do
      money = parsed.find { |c| c[:name] == "Money" }
      expect(money[:superclass]).to eq("Data")
    end
  end

  describe "module nesting" do
    before do
      write_file("billing/invoice.rb", <<~RUBY)
        module Billing
          class Invoice
            attr_accessor :total, :due_date
          end
        end
      RUBY
    end

    it "captures the module as the group" do
      invoice = parsed.find { |c| c[:name] == "Invoice" }
      expect(invoice[:module]).to eq("Billing")
    end
  end

  describe "classes with inheritance" do
    before do
      write_file("admin_user.rb", <<~RUBY)
        class AdminUser < User
          attr_accessor :role
        end
      RUBY
    end

    it "captures the superclass" do
      admin = parsed.find { |c| c[:name] == "AdminUser" }
      expect(admin[:superclass]).to eq("User")
    end
  end

  describe "colon-separated class names" do
    before do
      write_file("thing.rb", <<~RUBY)
        class Billing::LineItem < Struct.new(:desc, :price)
        end
      RUBY
    end

    it "uses the short name" do
      item = parsed.find { |c| c[:name] == "LineItem" }
      expect(item).not_to be_nil
      expect(item[:attributes].map { |a| a[:name] }).to contain_exactly("desc", "price")
    end
  end

  describe "scanning subdirectories" do
    before do
      write_file("lib/models/foo.rb", <<~RUBY)
        class Foo
          attr_accessor :bar
        end
      RUBY
    end

    it "finds files in nested directories" do
      foo = parsed.find { |c| c[:name] == "Foo" }
      expect(foo).not_to be_nil
    end
  end
end
