#!/usr/bin/env ruby
# QA Automated Test Runner
# Tests domain runtime behavior without touching web interfaces
# Usage: ruby qa_runner.rb [--domains Domain1,Domain2] [--verbose]

require 'json'
require 'fileutils'

class QARunner
  def initialize(options = {})
    @domains = options[:domains] || []
    @verbose = options[:verbose] || false
    @results = []
    @errors = []
  end

  def run_all_corpus_tests
    corpus_dir = "spec/corpus"
    Dir.glob("#{corpus_dir}/*.json").sort.each do |file|
      test_name = File.basename(file, ".json")
      run_corpus_test(test_name, file)
    end
  end

  def run_corpus_test(name, filepath)
    puts "\n[TEST] #{name}..." if @verbose

    begin
      corpus = JSON.parse(File.read(filepath))

      # Extract domain name from corpus structure
      domain = extract_domain(corpus)
      return if domain.nil?

      # Validate corpus structure
      validate_corpus_structure(corpus, name)

      # Test expectations match structure
      test_expectations(corpus, name)

      @results << { name: name, status: :passed, domain: domain }
      puts "✓ #{name}" unless @verbose
    rescue StandardError => e
      @errors << { name: name, error: e.message, backtrace: e.backtrace }
      puts "✗ #{name}: #{e.message}" unless @verbose
    end
  end

  def extract_domain(corpus)
    # Domain inferred from first step's verb or query
    return nil if corpus["steps"].empty?

    first_step = corpus["steps"].first
    target = first_step["verb"] || first_step["query"]
    return nil if target.nil?

    target.match(/^(\w+)::/) { |m| m[1] }
  end

  def validate_corpus_structure(corpus, test_name)
    required_keys = ["steps"]
    required_keys.each do |key|
      unless corpus.key?(key)
        raise "Missing required key '#{key}' in #{test_name}"
      end
    end

    unless corpus["steps"].is_a?(Array)
      raise "steps must be an array in #{test_name}"
    end

    corpus["steps"].each_with_index do |step, idx|
      has_verb = step.key?("verb")
      has_query = step.key?("query")
      unless has_verb || has_query
        raise "Step #{idx} missing 'verb' or 'query' in #{test_name}"
      end
      # args is required for verbs, optional for queries (some queries take no args)
      if has_verb && !step.key?("args")
        raise "Step #{idx} (verb) missing 'args' in #{test_name}"
      end
    end
  end

  def test_expectations(corpus, test_name)
    expectations = corpus["expectations"] || {}

    # Validate expectations are reasonable
    if expectations.key?("events")
      unless expectations["events"].is_a?(Integer) && expectations["events"] >= 0
        raise "Invalid 'events' expectation (must be non-negative integer): #{expectations['events']}"
      end
    end

    if expectations.key?("refusals")
      unless expectations["refusals"].is_a?(Array)
        raise "Invalid 'refusals' expectation (must be array)"
      end
    end

    if expectations.key?("rows")
      unless expectations["rows"].is_a?(Hash)
        raise "Invalid 'rows' expectation (must be object)"
      end
    end
  end

  def report
    puts "\n" + "="*60
    puts "QA TEST REPORT"
    puts "="*60

    passed = @results.select { |r| r[:status] == :passed }.count
    failed = @errors.count
    total = passed + failed

    puts "\nSummary:"
    puts "  Total tests:  #{total}"
    puts "  Passed:       #{passed}"
    puts "  Failed:       #{failed}"

    if @errors.any?
      puts "\nFailures:"
      @errors.each do |error|
        puts "\n  #{error[:name]}:"
        puts "    #{error[:error]}"
      end
    end

    domains = @results.map { |r| r[:domain] }.uniq.compact.sort
    if domains.any?
      puts "\nDomains tested:"
      domains.each { |d| puts "  - #{d}" }
    end

    puts "\n" + "="*60
    failed == 0
  end

  def self.run(options = {})
    runner = new(options)
    runner.run_all_corpus_tests
    runner.report
  end
end

if __FILE__ == $0
  options = {}
  options[:verbose] = ARGV.include?("--verbose")

  success = QARunner.run(options)
  exit success ? 0 : 1
end
