require "spec_helper"

RSpec.describe "Design Analysis — Conceptual Contours" do
  def validate(domain)
    v = Hecks::Validator.new(domain)
    [v.valid?, v.errors, v.warnings]
  end

  describe "Structure::TooManyAttributes" do
    it "warns when aggregate has 8+ attributes" do
      domain = Hecks.domain("Analysis") do
        aggregate("Bloated") do
          attribute :a, String; attribute :b, String; attribute :c, String
          attribute :d, String; attribute :e, String; attribute :f, String
          attribute :g, String; attribute :h, String
          command("CreateBloated") { attribute :a, String }
        end
      end
      _, _, warnings = validate(domain)
      expect(warnings.any? { |w| w.include?("Bloated") && w.include?("8 attributes") }).to be true
    end

    it "does not warn below threshold" do
      domain = Hecks.domain("Analysis") do
        aggregate("Lean") do
          attribute :a, String; attribute :b, String
          command("CreateLean") { attribute :a, String }
        end
      end
      _, _, warnings = validate(domain)
      expect(warnings.none? { |w| w.include?("Lean") && w.include?("attributes") }).to be true
    end
  end

  describe "Structure::TooManyValueObjects" do
    it "warns when aggregate has 5+ value objects" do
      domain = Hecks.domain("Analysis") do
        aggregate("Wide") do
          attribute :name, String
          value_object("V1") { attribute :x, String }
          value_object("V2") { attribute :x, String }
          value_object("V3") { attribute :x, String }
          value_object("V4") { attribute :x, String }
          value_object("V5") { attribute :x, String }
          command("CreateWide") { attribute :name, String }
        end
      end
      _, _, warnings = validate(domain)
      expect(warnings.any? { |w| w.include?("Wide") && w.include?("5 value objects") }).to be true
    end

    it "does not warn below threshold" do
      domain = Hecks.domain("Analysis") do
        aggregate("Narrow") do
          attribute :name, String
          value_object("V1") { attribute :x, String }
          command("CreateNarrow") { attribute :name, String }
        end
      end
      _, _, warnings = validate(domain)
      expect(warnings.none? { |w| w.include?("Narrow") && w.include?("value objects") }).to be true
    end
  end

  describe "Structure::MissingLifecycle" do
    it "warns when aggregate has status attribute but no lifecycle" do
      domain = Hecks.domain("Analysis") do
        aggregate("Task") do
          attribute :name, String
          attribute :status, String
          command("CreateTask") { attribute :name, String }
        end
      end
      _, _, warnings = validate(domain)
      expect(warnings.any? { |w| w.include?("Task") && w.include?("status") && w.include?("lifecycle") }).to be true
    end

    it "does not warn when lifecycle is defined" do
      domain = Hecks.domain("Analysis") do
        aggregate("Task") do
          attribute :name, String
          attribute :status, String, default: "open" do
            transition "CloseTask" => "closed", from: "open"
          end
          command("CreateTask") { attribute :name, String }
          command("CloseTask") { reference_to "Task" }
        end
      end
      _, _, warnings = validate(domain)
      expect(warnings.none? { |w| w.include?("Task") && w.include?("lifecycle") }).to be true
    end

    it "does not warn when no status attribute" do
      domain = Hecks.domain("Analysis") do
        aggregate("Widget") do
          attribute :name, String
          command("CreateWidget") { attribute :name, String }
        end
      end
      _, _, warnings = validate(domain)
      expect(warnings.none? { |w| w.include?("Widget") && w.include?("lifecycle") }).to be true
    end
  end

  describe "Structure::CohesionAnalysis" do
    it "warns when commands touch fewer than half the attributes" do
      domain = Hecks.domain("Analysis") do
        aggregate("Unfocused") do
          attribute :a, String; attribute :b, String
          attribute :c, String; attribute :d, String
          command("DoThing") { attribute :a, String }
        end
      end
      _, _, warnings = validate(domain)
      expect(warnings.any? { |w| w.include?("Unfocused") && w.include?("cohesion") }).to be true
    end

    it "does not warn when commands cover most attributes" do
      domain = Hecks.domain("Analysis") do
        aggregate("Focused") do
          attribute :a, String; attribute :b, String; attribute :c, String
          command("DoA") { attribute :a, String; attribute :b, String; attribute :c, String }
        end
      end
      _, _, warnings = validate(domain)
      expect(warnings.none? { |w| w.include?("Focused") && w.include?("cohesion") }).to be true
    end

    it "skips aggregates with fewer than 3 attributes" do
      domain = Hecks.domain("Analysis") do
        aggregate("Tiny") do
          attribute :a, String; attribute :b, String
          command("DoTiny") { attribute :a, String }
        end
      end
      _, _, warnings = validate(domain)
      expect(warnings.none? { |w| w.include?("Tiny") && w.include?("cohesion") }).to be true
    end
  end

  describe "Structure::GodAggregate" do
    it "warns when aggregate exceeds all three thresholds" do
      domain = Hecks.domain("Analysis") do
        aggregate("Monolith") do
          8.times { |i| attribute :"a#{i}", String }
          3.times { |i| value_object("V#{i}") { attribute :x, String } }
          8.times { |i| command("Cmd#{i}") { attribute :"a#{i}", String } }
        end
      end
      _, _, warnings = validate(domain)
      expect(warnings.any? { |w| w.include?("Monolith") && w.include?("god aggregate") }).to be true
    end

    it "does not warn when only some thresholds are exceeded" do
      domain = Hecks.domain("Analysis") do
        aggregate("HalfBig") do
          8.times { |i| attribute :"a#{i}", String }
          command("CreateHalfBig") { attribute :a0, String }
        end
      end
      _, _, warnings = validate(domain)
      expect(warnings.none? { |w| w.include?("HalfBig") && w.include?("god aggregate") }).to be true
    end
  end
end
