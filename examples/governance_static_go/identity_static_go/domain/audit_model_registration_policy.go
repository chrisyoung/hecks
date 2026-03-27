package domain

// AuditModelRegistration reacts to RegisteredModel
// and triggers RecordEntry

type AuditModelRegistration struct {}

func (p AuditModelRegistration) EventName() string { return "RegisteredModel" }

func (p AuditModelRegistration) Execute(event interface{}) {
	// trigger aggregate not found for RecordEntry
}
