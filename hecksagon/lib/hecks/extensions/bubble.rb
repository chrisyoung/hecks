# HecksBubble
#
# Anti-corruption layer (ACL) extension for Hecks domains. A bubble context
# shields a domain from legacy or external system naming by mapping between
# foreign field names and domain field names. Translations can rename fields,
# apply transforms, and reverse-map domain data back to legacy format.
#
# Extension type: driven. Register via Hecksagon or use directly.
#
#   context = HecksBubble::Context.new
#   context.map_aggregate :Pizza do
#     from_legacy :pie_name, to: :name
#     from_legacy :pie_desc, to: :description, transform: ->(v) { v.to_s.strip }
#   end
#
#   clean = context.translate(:Pizza, :create, pie_name: "Margherita", pie_desc: " Classic ")
#   # => { name: "Margherita", description: "Classic" }
#
#   legacy = context.reverse(:Pizza, name: "Margherita", description: "Classic")
#   # => { pie_name: "Margherita", pie_desc: "Classic" }
#
require "hecks"

module HecksBubble
  VERSION = "2026.04.01.1"
end

require_relative "bubble/aggregate_mapping"
require_relative "bubble/context"

Hecks.describe_extension(:bubble,
  description: "Anti-corruption layer for legacy field translation",
  adapter_type: :driven,
  config: {},
  wires_to: :command_bus)

Hecks.register_extension(:bubble) do |domain_mod, domain, runtime|
  # Bubble contexts are wired manually per-domain. This hook makes the
  # extension visible in the extension registry and available for
  # introspection via `Hecks.driven_extensions`.
end
