require "spec_helper"

RSpec.describe "Conceptual Contour Validators" do
  def validate(domain)
    v = Hecks::Validator.new(domain)
    [v.valid?, v.errors, v.warnings]
  end

  describe "Structure::TooManyAttributes" do
    it "warns when aggregate has 8+ attributes" do
      domain = Hecks.domain("Test") do
        aggregate("Big") do
          8.times { |i| attribute :"attr_#{i}", String }
          command("CreateBig") { attribute :name, String }
        end
      end
      _, _, warnings = validate(domain)
      expect(warnings.any? { |w| w.include?("Big") && w.include?("8 attributes") }).to be true
    end

    it "does not warn under threshold" do
      domain = Hecks.domain("Test") do
        aggregate("Small") do
          attribute :name, String
          command("CreateSmall") { attribute :name, String }
        end
      end
      _, _, warnings = validate(domain)
      expect(warnings.none? { |w| w.include?("attributes") && w.include?("Small") }).to be true
    end
  end

  describe "Structure::TooManyValueObjects" do
    it "warns when aggregate has 5+ value objects" do
      domain = Hecks.domain("Test") do
        aggregate("Complex") do
          attribute :name, String
          5.times { |i| value_object("Vo#{i}") { attribute :x, String } }
          command("CreateComplex") { attribute :name, String }
        end
      end
      _, _, warnings = validate(domain)
      expect(warnings.any? { |w| w.include?("Complex") && w.include?("5 value objects") }).to be true
    end
  end

  describe "Structure::MissingLifecycle" do
    it "warns when status attribute lacks lifecycle" do
      domain = Hecks.domain("Test") do
        aggregate("Task") do
          attribute :status, String
          command("CreateTask") { attribute :name, String }
        end
      end
      _, _, warnings = validate(domain)
      expect(warnings.any? { |w| w.include?("Task") && w.include?(":status") && w.include?("lifecycle") }).to be true
    end

    it "does not warn when lifecycle is present" do
      domain = Hecks.domain("Test") do
        aggregate("Task") do
          attribute :name, String
          attribute :status, String, default: "open" do
            transition "CompleteTask" => "done"
          end
          command("CreateTask") { attribute :name, String }
          command("CompleteTask") { attribute :name, String }
        end
      end
      _, _, warnings = validate(domain)
      expect(warnings.none? { |w| w.include?("Task") && w.include?("lifecycle") }).to be true
    end
  end

  describe "Structure::CohesionAnalysis" do
    it "warns when commands touch disjoint attribute sets" do
      domain = Hecks.domain("Test") do
        aggregate("Account") do
          attribute :name, String
          attribute :balance, Integer
          attribute :email, String
          attribute :phone, String
          command("UpdateProfile") { attribute :email, String }
          command("Deposit") { attribute :balance, Integer }
        end
      end
      _, _, warnings = validate(domain)
      expect(warnings.any? { |w| w.include?("Account") && w.include?("cohesion") }).to be true
    end
  end

  describe "Structure::GodAggregate" do
    it "warns when multiple complexity thresholds are exceeded" do
      domain = Hecks.domain("Test") do
        aggregate("Mega") do
          6.times { |i| attribute :"a#{i}", String }
          3.times { |i| value_object("Vo#{i}") { attribute :x, String } }
          command("CreateMega") { attribute :name, String }
        end
      end
      _, _, warnings = validate(domain)
      expect(warnings.any? { |w| w.include?("Mega") && w.include?("god aggregate") }).to be true
    end

    it "does not warn when only one threshold is exceeded" do
      domain = Hecks.domain("Test") do
        aggregate("Normal") do
          attribute :name, String
          7.times { |i| command("Cmd#{i}") { attribute :name, String } }
        end
      end
      _, _, warnings = validate(domain)
      expect(warnings.none? { |w| w.include?("god aggregate") }).to be true
    end
  end
end
