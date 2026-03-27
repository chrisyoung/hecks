# NotificationService
#
# Event-driven notification routing. Auto-subscribes to the shared
# event bus when loaded. Routes events to recipients by urgency.
#
class NotificationService
  ROUTES = {
    "RegisteredModel"      => { recipients: ["governance_board"], channel: :email, urgency: :normal },
    "SuspendedModel"       => { recipients: ["model_owner", "compliance_team"], channel: :email, urgency: :urgent },
    "ClassifiedRisk"       => { recipients: ["governance_board"], channel: :email, urgency: :urgent,
                                condition: ->(e) { %w[high critical].include?(e.risk_level) } },
    "ApprovedModel"        => { recipients: ["model_owner"], channel: :email, urgency: :normal },
    "RejectedReview"       => { recipients: ["model_owner", "assessor"], channel: :email, urgency: :normal },
    "RequestedChanges"     => { recipients: ["model_owner"], channel: :email, urgency: :normal },
    "RevokedAgreement"     => { recipients: ["data_steward", "model_owner"], channel: :email, urgency: :normal },
    "ApprovedReview"       => { recipients: ["model_owner"], channel: :email, urgency: :normal },
    "ReportedIncident"     => { recipients: ["compliance_team", "governance_board"], channel: :email, urgency: :urgent },
    "DeployedModel"        => { recipients: ["governance_board"], channel: :email, urgency: :normal },
    "SuspendedVendor"      => { recipients: ["vendor_manager", "model_owners"], channel: :email, urgency: :urgent },
    "ApprovedExemption"    => { recipients: ["compliance_team"], channel: :email, urgency: :normal },
  }.freeze

  def self.route(event)
    event_name = event.class.name.split("::").last
    config = ROUTES[event_name]
    return unless config
    return if config[:condition] && !config[:condition].call(event)

    deliver(event_name, event, config)
  end

  def self.deliver(event_name, event, config)
    @log ||= []
    @log << { event: event_name, recipients: config[:recipients],
              channel: config[:channel], urgency: config[:urgency], at: Time.now }
    puts "  [notify] #{config[:urgency]} #{config[:channel]} to #{config[:recipients].join(', ')}: #{event_name}"
  end

  def self.log = @log || []
  def self.clear_log = @log = []

  # Auto-subscribe when loaded
  if defined?(Hecks) && Hecks.respond_to?(:event_bus) && Hecks.event_bus
    ROUTES.each_key do |event_name|
      Hecks.event_bus.subscribe(event_name) { |e| route(e) }
    end
  end
end
