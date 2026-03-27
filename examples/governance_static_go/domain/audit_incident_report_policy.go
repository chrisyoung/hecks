package domain

// AuditIncidentReport reacts to ReportedIncident
// and triggers RecordEntry

type AuditIncidentReport struct {}

func (p AuditIncidentReport) EventName() string { return "ReportedIncident" }

func (p AuditIncidentReport) Execute(event interface{}, AuditLogRepo AuditLogRepository) error {
	cmd := RecordEntry{}
	_, _, err := cmd.Execute(AuditLogRepo)
	return err
}
