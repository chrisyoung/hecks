# HecksPolicyTracing
#
# Driven extension that instruments policy execution with trace callbacks.
# Wraps PolicySetup#execute_policy to capture timing, condition results,
# and action details for every reactive policy fired. Traces are stored
# in-memory and accessible via Hecks.policy_traces.
#
# Trace data format:
#   { policy:, event:, condition_result:, action:, duration_ms:, timestamp: }
#
# Usage:
#   app = Hecks.boot(__dir__) do
#     extend :policy_tracing
#   end
#
#   Pizza.create(name: "Margherita")
#   Hecks.policy_traces
#   # => [{ policy: "NotifyKitchen", event: "CreatedPizza", ... }]
#
Hecks.describe_extension(:policy_tracing,
  description: "Policy execution tracing with timing and condition data",
  adapter_type: :driven,
  config: {},
  wires_to: :event_bus)

Hecks.register_extension(:policy_tracing) do |_domain_mod, _domain, runtime|
  traces = []
  Hecks.instance_variable_set(:@_policy_traces, traces)
  Hecks.define_singleton_method(:policy_traces) { @_policy_traces }

  original_execute = runtime.method(:execute_policy)

  runtime.define_singleton_method(:execute_policy) do |policy, policy_key, event|
    start = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    condition_result = !policy.condition || policy.condition.call(event)

    original_execute.call(policy, policy_key, event)

    duration = ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - start) * 1000).round(2)

    traces << {
      policy: policy.name,
      event: event.class.name.split("::").last,
      condition_result: condition_result,
      action: policy.trigger_command,
      duration_ms: duration,
      timestamp: Time.now
    }
  end
end
