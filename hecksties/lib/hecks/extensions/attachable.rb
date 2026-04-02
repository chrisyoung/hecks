# Hecks::Attachable
#
# File attachment extension for Hecks domains. Reads +:attachable+ tags
# from the hecksagon IR's aggregate_capabilities and generates per-attribute
# attachment methods on domain aggregate classes.
#
# When registered, this extension:
# - Adds +attach_<attr>(metadata)+ methods for storing attachment metadata
# - Adds +<attr>_attachments+ methods for listing attachments
# - Adds +attachable_fields+ introspection on the domain module
#
# Future gem: hecks_attachable
#
#   # Hecksagon DSL
#   aggregate "Patient" do
#     avatar.attachable
#   end
#
#   # Usage
#   patient = Patient.create(name: "Alice")
#   Patient.attach_avatar(patient.id, filename: "photo.jpg")
#   Patient.avatar_attachments(patient.id)  # => [{ filename: "photo.jpg", ref_id: "..." }]
#   PatientsDomain.attachable_fields         # => { "Patient" => [:avatar] }
#
require "securerandom"
require_relative "../runtime/attachment_store"

module Hecks; end
module Hecks::Attachable
  # Extract attachable fields from hecksagon aggregate_capabilities tags.
  #
  # @param hecksagon [Hecksagon::Structure::Hecksagon] the hecksagon IR
  # @return [Hash{String => Array<Symbol>}] aggregate name to attachable attribute names
  def self.attachable_fields(hecksagon)
    return {} unless hecksagon&.aggregate_capabilities
    hecksagon.aggregate_capabilities.each_with_object({}) do |(agg_name, tags), result|
      attrs = tags.select { |t| t[:tag] == :attachable }.map { |t| t[:attribute].to_sym }
      result[agg_name] = attrs unless attrs.empty?
    end
  end
end

Hecks.describe_extension(:attachable,
  description: "File attachment metadata for aggregate attributes",
  adapter_type: :driven,
  config: {},
  wires_to: :repository)

Hecks.register_extension(:attachable) do |domain_mod, domain, runtime|
  hecksagon = runtime.hecksagon
  fields = Hecks::Attachable.attachable_fields(hecksagon)
  store = Hecks::Runtime::MemoryAttachmentStore.new

  # Expose the attachment store on the runtime for testing/access.
  runtime.instance_variable_set(:@attachment_store, store)
  runtime.define_singleton_method(:attachment_store) { @attachment_store }

  # Generate per-attribute methods on aggregate classes.
  fields.each do |agg_name, attrs|
    agg_class = domain_mod.const_get(agg_name)

    attrs.each do |attr|
      # attach_<attr>(entity_id, metadata) — store attachment metadata
      agg_class.define_singleton_method(:"attach_#{attr}") do |entity_id, **metadata|
        store.store(entity_id.to_s, attr, metadata)
      end

      # <attr>_attachments(entity_id) — list all attachments for the attribute
      agg_class.define_singleton_method(:"#{attr}_attachments") do |entity_id|
        store.list(entity_id.to_s, attr)
      end
    end
  end

  # Introspection: domain_mod.attachable_fields
  #
  # @return [Hash{String => Array<Symbol>}] aggregate name to attachable field names
  domain_mod.define_singleton_method(:attachable_fields) do
    fields
  end
end
