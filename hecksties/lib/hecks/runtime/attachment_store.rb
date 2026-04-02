# Hecks::Runtime::MemoryAttachmentStore
#
# In-memory storage for file attachment metadata. Implements the
# attachment store interface used by the :attachable extension.
# Each attachment is stored as a hash keyed by aggregate ID and
# attribute name.
#
# Interface:
#   store.store(agg_id, attr, metadata)   # => metadata with :ref_id
#   store.list(agg_id, attr)              # => [metadata, ...]
#   store.delete(agg_id, attr, ref_id)    # => deleted metadata or nil
#   store.clear                           # => reset all data
#
# Future gem: hecks_attachments
#
#   store = Hecks::Runtime::MemoryAttachmentStore.new
#   store.store("abc-123", :avatar, { filename: "photo.jpg", content_type: "image/jpeg" })
#   store.list("abc-123", :avatar)
#
module Hecks
  class Runtime
    class MemoryAttachmentStore
      def initialize
        @data = {}
      end

      # Store attachment metadata for an aggregate attribute.
      #
      # @param agg_id [String] the aggregate instance ID
      # @param attr [Symbol, String] the attribute name
      # @param metadata [Hash] attachment metadata (filename, content_type, etc.)
      # @return [Hash] the stored metadata with an assigned :ref_id
      def store(agg_id, attr, metadata)
        key = [agg_id.to_s, attr.to_sym]
        @data[key] ||= []
        entry = metadata.merge(ref_id: SecureRandom.uuid)
        @data[key] << entry
        entry
      end

      # List all attachments for an aggregate attribute.
      #
      # @param agg_id [String] the aggregate instance ID
      # @param attr [Symbol, String] the attribute name
      # @return [Array<Hash>] stored attachment metadata entries
      def list(agg_id, attr)
        key = [agg_id.to_s, attr.to_sym]
        @data[key] || []
      end

      # Delete a specific attachment by ref_id.
      #
      # @param agg_id [String] the aggregate instance ID
      # @param attr [Symbol, String] the attribute name
      # @param ref_id [String] the attachment reference ID to remove
      # @return [Hash, nil] the deleted entry, or nil if not found
      def delete(agg_id, attr, ref_id)
        key = [agg_id.to_s, attr.to_sym]
        entries = @data[key] || []
        idx = entries.index { |e| e[:ref_id] == ref_id }
        return nil unless idx
        entries.delete_at(idx)
      end

      # Clear all stored attachment data.
      #
      # @return [void]
      def clear
        @data.clear
      end
    end
  end
end
