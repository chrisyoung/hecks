package domain

// AuditModelSuspension reacts to SuspendedModel
// and triggers RecordEntry

type AuditModelSuspension struct {}

func (p AuditModelSuspension) EventName() string { return "SuspendedModel" }

func (p AuditModelSuspension) Execute(event interface{}) {
	// trigger aggregate not found for RecordEntry
}
