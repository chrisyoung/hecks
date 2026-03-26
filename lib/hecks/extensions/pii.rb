# HecksPii
#
# PII protection extension for Hecks domains. Reads `pii: true` markers
# on attributes and provides masking, redaction, and erasure capabilities.
#
# Future gem: hecks_pii
#
#   # DSL
#   attribute :email, String, pii: true
#
#   # Gemfile
#   gem "cats_domain"
#   gem "hecks_pii"
#
#   # Erasure
#   CatsDomain.erase_pii(customer_id)
#
module HecksPii
  # Mask a value for display (audit logs, etc.)
  def self.mask(value)
    return nil if value.nil?
    s = value.to_s
    return "[REDACTED]" if s.length < 4
    "#{s[0]}#{"*" * (s.length - 2)}#{s[-1]}"
  end

  # Get PII field names for an aggregate
  def self.pii_fields(aggregate)
    aggregate.attributes.select(&:pii?).map(&:name)
  end
end

Hecks.describe_extension(:pii,
  description: "PII field encryption and masking",
  config: {},
  wires_to: :repository)

Hecks.register_extension(:pii) do |domain_mod, domain, runtime|
  # Add erase_pii method to domain module
  domain_mod.define_singleton_method(:erase_pii) do |entity_id|
    domain.aggregates.each do |agg|
      pii_names = HecksPii.pii_fields(agg)
      next if pii_names.empty?

      repo = runtime[agg.name]
      entity = repo.find(entity_id)
      next unless entity

      nulled_attrs = {}
      pii_names.each { |name| nulled_attrs[name] = nil }
      agg_class = domain_mod.const_get(agg.name)
      erased = agg_class.new(id: entity.id, **nulled_attrs)
      repo.save(erased)
    end
  end

  # Add pii_fields introspection to domain module
  domain_mod.define_singleton_method(:pii_fields) do
    domain.aggregates.each_with_object({}) do |agg, h|
      fields = HecksPii.pii_fields(agg)
      h[agg.name] = fields unless fields.empty?
    end
  end

  # Patch audit extension to mask PII if both are loaded
  if Hecks.extension_registry[:audit]
    pii_lookup = {}
    domain.aggregates.each do |agg|
      agg.commands.each do |cmd|
        fqn = "#{domain_mod.name}::#{agg.name}::Commands::#{cmd.name}"
        pii_names = HecksPii.pii_fields(agg)
        pii_lookup[fqn] = pii_names unless pii_names.empty?
      end
    end

    runtime.use :pii_mask do |command, next_handler|
      result = next_handler.call
      pii_names = pii_lookup[command.class.name]
      if pii_names && domain_mod.respond_to?(:audit_log)
        entry = domain_mod.audit_log.last
        if entry && entry[:attributes]
          pii_names.each do |name|
            entry[:attributes][name] = HecksPii.mask(entry[:attributes][name]) if entry[:attributes].key?(name)
          end
        end
      end
      result
    end
  end
end
