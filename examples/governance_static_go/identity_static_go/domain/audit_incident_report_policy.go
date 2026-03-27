package domain

// AuditIncidentReport reacts to ReportedIncident
// and triggers RecordEntry

type AuditIncidentReport struct {}

func (p AuditIncidentReport) EventName() string { return "ReportedIncident" }

func (p AuditIncidentReport) Execute(event interface{}) {
	// trigger aggregate not found for RecordEntry
}
