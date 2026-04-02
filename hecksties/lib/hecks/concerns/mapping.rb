# Hecks::Concerns::Mapping
#
# Shared mapping from world concerns to extensions and capabilities.
# Extracted from WorldConcernsPrompt so that both the onboarding CLI
# and the runtime boot sequence share a single source of truth.
#
# Usage:
#   Hecks::Concerns::Mapping.extensions_for(:privacy)    # => [:pii]
#   Hecks::Concerns::Mapping.capabilities_for(:privacy)  # => [:audit]
#   Hecks::Concerns::Mapping.resolve(:transparency)
#   # => { extensions: [:audit], capabilities: [:audit] }
#
module Hecks
  module Concerns
    module Mapping
      # Maps a world concern to the extension that enforces it.
      CONCERN_TO_EXTENSION = {
        privacy:        :pii,
        transparency:   :audit,
        consent:        :auth,
        security:       :auth,
        equity:         :tenancy,
        sustainability: :rate_limit
      }.freeze

      # Maps a world concern to capabilities that should be activated.
      # Capabilities are higher-level behaviors composed from extensions.
      CONCERN_TO_CAPABILITIES = {
        privacy:      [:audit],
        transparency: [:audit],
        consent:      [],
        security:     [],
        equity:       [],
        sustainability: []
      }.freeze

      VALID_CONCERNS = CONCERN_TO_EXTENSION.keys.freeze

      # Returns the extensions needed for a single concern.
      #
      # @param concern [Symbol] a world concern name
      # @return [Array<Symbol>] extension names
      def self.extensions_for(concern)
        ext = CONCERN_TO_EXTENSION[concern.to_sym]
        ext ? [ext] : []
      end

      # Returns the capabilities needed for a single concern.
      #
      # @param concern [Symbol] a world concern name
      # @return [Array<Symbol>] capability names
      def self.capabilities_for(concern)
        CONCERN_TO_CAPABILITIES.fetch(concern.to_sym, [])
      end

      # Resolves a concern to both its extensions and capabilities.
      #
      # @param concern [Symbol] a world concern name
      # @return [Hash] with :extensions and :capabilities arrays
      def self.resolve(concern)
        {
          extensions: extensions_for(concern),
          capabilities: capabilities_for(concern)
        }
      end

      # Resolves multiple concerns, deduplicating results.
      #
      # @param concerns [Array<Symbol>] concern names
      # @return [Hash] with :extensions and :capabilities arrays
      def self.resolve_all(concerns)
        exts = []
        caps = []
        concerns.each do |c|
          r = resolve(c)
          exts.concat(r[:extensions])
          caps.concat(r[:capabilities])
        end
        { extensions: exts.uniq, capabilities: caps.uniq }
      end
    end
  end
end
