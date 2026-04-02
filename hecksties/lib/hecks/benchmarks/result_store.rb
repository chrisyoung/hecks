require "json"

module Hecks
  module Benchmarks

    # Hecks::Benchmarks::ResultStore
    #
    # Persists benchmark results as JSON. Supports loading the latest
    # baseline for regression comparison and appending new results.
    #
    #   ResultStore.save(results, path: "benchmarks.json")
    #   baseline = ResultStore.load("benchmarks.json")
    #
    class ResultStore
      DEFAULT_PATH = "benchmarks.json"

      # Save benchmark results to a JSON file, appending to existing runs.
      #
      # @param results [Hash] benchmark results from Suite#run
      # @param path [String] file path for the JSON store
      # @return [void]
      def self.save(results, path: DEFAULT_PATH)
        runs = load_all(path)
        runs << results
        File.write(path, JSON.pretty_generate(runs))
      end

      # Load the most recent benchmark result from the store.
      #
      # @param path [String] file path for the JSON store
      # @return [Hash, nil] the latest result, or nil if no results exist
      def self.load(path = DEFAULT_PATH)
        runs = load_all(path)
        return nil if runs.empty?
        symbolize(runs.last)
      end

      # Load all benchmark runs from the store.
      #
      # @param path [String] file path for the JSON store
      # @return [Array<Hash>] all stored runs
      def self.load_all(path = DEFAULT_PATH)
        return [] unless File.exist?(path)
        JSON.parse(File.read(path))
      rescue JSON::ParserError
        []
      end

      # Symbolize string keys in a hash for consistent access.
      #
      # @param hash [Hash] hash with string keys
      # @return [Hash] hash with symbol keys
      def self.symbolize(hash)
        hash.each_with_object({}) { |(k, v), h| h[k.to_sym] = v }
      end
    end
  end
end
