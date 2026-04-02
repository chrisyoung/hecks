# = Hecks::Conventions::CommandContract
#
# Canonical command method name derivation. Centralizes the suffix-stripping
# logic that turns CreatePolicy into .create on GovernancePolicy.
#
# Used by the Ruby runtime, spec generator, and Go target to derive
# identical method names from the same rule.
#
#   CommandContract.method_name("CreatePolicy", "GovernancePolicy")   # => :create
#   CommandContract.method_name("ActivatePolicy", "GovernancePolicy") # => :activate
#   CommandContract.method_name("CreatePizza", "Pizza")               # => :create
#
module Hecks::Conventions
  module CommandContract
    # Derives the short Ruby method name for a command on an aggregate.
    # Strips the longest matching right-suffix of the aggregate name.
    #
    # @param cmd_name [String] the command class name e.g. "CreatePolicy"
    # @param agg_name [String] the aggregate class name e.g. "GovernancePolicy"
    # @return [Symbol] the derived method name e.g. :create
    def self.method_name(cmd_name, agg_name)
      full = Hecks::Utils.underscore(cmd_name)
      agg_suffixes(agg_name).each do |suffix|
        stripped = full.sub(/_#{suffix}$/, "")
        return stripped.to_sym if stripped != full
      end
      full.to_sym
    end

    # Returns all right-suffix variants of the aggregate snake name.
    # "governance_policy" => ["governance_policy", "policy"]
    #
    # @param agg_name [String] aggregate name (camel or snake case)
    # @return [Array<String>] suffix variants, longest first
    def self.agg_suffixes(agg_name)
      agg_snake = Hecks::Utils.underscore(agg_name)
      agg_snake.split("_").each_index.map { |i|
        agg_snake.split("_").drop(i).join("_")
      }.uniq
    end

    # True when the attribute name looks like a self-referencing foreign key
    # for the given aggregate. Matches `_id` suffix against all aggregate
    # name suffixes (e.g. `policy_id` matches `GovernancePolicy`).
    #
    # @param attr_name [String] the attribute name e.g. "policy_id"
    # @param agg_name [String] the aggregate name e.g. "GovernancePolicy"
    # @return [Boolean]
    def self.reference_attribute?(attr_name, agg_name)
      name = attr_name.to_s
      return false unless name.end_with?("_id")
      agg_suffixes(agg_name).any? { |s| name == "#{s}_id" }
    end

    # Find the self-referencing `_id` attribute on a command for the given
    # aggregate. Returns nil for create commands (no self-ref).
    #
    # @param cmd [Command] the command IR
    # @param agg_name [String] the aggregate name
    # @return [Attribute, nil] the self-ref attribute, or nil
    def self.find_self_ref(cmd, agg_name)
      cmd.attributes.find { |a| reference_attribute?(a.name, agg_name) }
    end
  end
end
