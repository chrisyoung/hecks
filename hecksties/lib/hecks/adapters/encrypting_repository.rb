# Hecks::Adapters::EncryptingRepository
#
# Repository decorator that transparently encrypts marked attributes on
# save and decrypts them on find/all/query. Wraps any inner repository
# (memory, SQL, etc.) using the same decorator pattern as
# OwnershipScopedRepository.
#
# Fields to encrypt are determined by the aggregate IR (attributes with
# +encrypted: true+). Nil values pass through without encryption.
#
#   repo = Hecks::Adapters::EncryptingRepository.new(
#     inner_repo,
#     aggregate: pizza_agg,
#     encryptor: Hecks::Adapters::TestEncryptor.new,
#     aggregate_class: Pizza
#   )
#   repo.save(Pizza.new(name: "Margherita", ssn: "123-45-6789"))
#   repo.find(id).ssn  # => "123-45-6789" (decrypted transparently)
#
module Hecks
  module Adapters
    class EncryptingRepository
      # @param inner_repo [Object] the underlying repository to wrap
      # @param aggregate [Hecks::DomainModel::Structure::Aggregate] the aggregate IR
      # @param encryptor [#encrypt, #decrypt] encryption backend
      # @param aggregate_class [Class] the runtime aggregate class for rebuilding
      def initialize(inner_repo, aggregate:, encryptor:, aggregate_class:)
        @inner = inner_repo
        @encryptor = encryptor
        @aggregate_class = aggregate_class
        @encrypted_fields = aggregate.attributes
          .select(&:encrypted?)
          .map(&:name)
      end

      # Find a record by ID and decrypt encrypted fields.
      def find(id)
        record = @inner.find(id)
        decrypt_record(record)
      end

      # Return all records with encrypted fields decrypted.
      def all
        @inner.all.map { |r| decrypt_record(r) }
      end

      # Encrypt marked fields and persist to the inner repository.
      def save(aggregate)
        @inner.save(encrypt_record(aggregate))
      end

      # Delete a record by ID (delegates directly).
      def delete(id)
        @inner.delete(id)
      end

      # Return count of records (delegates directly).
      def count
        @inner.count
      end

      # Remove all records (delegates directly).
      def clear
        @inner.clear
      end

      # Query records with encrypted fields decrypted in results.
      def query(**kwargs)
        @inner.query(**kwargs).map { |r| decrypt_record(r) }
      end

      private

      def encrypt_record(aggregate)
        return aggregate if @encrypted_fields.empty?

        attrs = extract_attrs(aggregate)
        @encrypted_fields.each do |field|
          val = attrs[field]
          attrs[field] = @encryptor.encrypt(val) unless val.nil?
        end
        @aggregate_class.new(**attrs)
      end

      def decrypt_record(record)
        return record if record.nil? || @encrypted_fields.empty?

        attrs = extract_attrs(record)
        @encrypted_fields.each do |field|
          val = attrs[field]
          attrs[field] = @encryptor.decrypt(val) unless val.nil?
        end
        @aggregate_class.new(**attrs)
      end

      def extract_attrs(aggregate)
        hash = {}
        hash[:id] = aggregate.id if aggregate.respond_to?(:id)
        @aggregate_class.hecks_attributes.each do |attr_def|
          name = attr_def.respond_to?(:name) ? attr_def.name : attr_def.to_sym
          hash[name] = aggregate.public_send(name) if aggregate.respond_to?(name)
        end
        hash
      end
    end
  end
end
