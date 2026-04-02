# HecksPolicyTracing
#
# Extension that traces reactive policy execution. Records each policy
# invocation with the policy name, trigger event, timestamp, and whether
# the condition passed. Access traces via +Hecks.policy_traces+.
#
# Usage:
#   app = Hecks.boot(__dir__)
#   app.extend(:policy_tracing)
#   Pizza.create(name: "Margherita")
#   Hecks.policy_traces  # => [{ policy: "AutoReady", ... }]
#
Hecks.describe_extension(:policy_tracing,
  description: "Trace reactive policy execution for debugging",
  adapter_type: :driven,
  config: {},
  wires_to: :event_bus)

Hecks.register_extension(:policy_tracing) do |_domain_mod, _domain, runtime|
  traces = []
  Hecks.instance_variable_set(:@_policy_traces, traces)

  Hecks.define_singleton_method(:policy_traces) { @_policy_traces.dup }
  Hecks.define_singleton_method(:clear_policy_traces) { @_policy_traces.clear }

  tracer = Module.new do
    define_method(:execute_policy) do |policy, policy_key, event|
      trace = {
        policy: policy.name,
        event: Hecks::Utils.const_short_name(event),
        timestamp: Time.now,
        condition_met: !policy.condition || policy.condition.call(event)
      }
      traces << trace
      super(policy, policy_key, event)
    end
  end
  runtime.singleton_class.prepend(tracer)
end
