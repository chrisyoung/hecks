# = HecksFeatures
#
# Vertical slice architecture for Hecks. Extracts vertical slices from
# domain reactive chains, validates slice boundaries, and generates
# Mermaid diagrams showing each use case as a self-contained column.
#
# A vertical slice is everything triggered by a single command: the command,
# its event, any policies it fires, and all downstream commands. Built on
# top of FlowGenerator's reactive chain tracing.
#
#   require "hecks_features"
#   domain.slices          # => [VerticalSlice, ...]
#   domain.slices_diagram  # => Mermaid flowchart
#
require_relative "hecks_features/vertical_slice"
require_relative "hecks_features/slice_extractor"
require_relative "hecks_features/leaky_slice_detection"
require_relative "hecks_features/slice_diagram"
require_relative "hecks_features/domain_mixin"

Hecks::DomainModel::Structure::Domain.include(HecksFeatures::DomainMixin)
