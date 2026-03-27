package domain

// AuditModelRegistration reacts to RegisteredModel
// and triggers RecordEntry

type AuditModelRegistration struct {}

func (p AuditModelRegistration) EventName() string { return "RegisteredModel" }

func (p AuditModelRegistration) Execute(event interface{}, AuditLogRepo AuditLogRepository) error {
	cmd := RecordEntry{}
	_, _, err := cmd.Execute(AuditLogRepo)
	return err
}
