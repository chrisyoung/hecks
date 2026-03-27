package domain

// SuspendOnCriticalIncident reacts to ReportedIncident
// and triggers SuspendModel

type SuspendOnCriticalIncident struct {}

func (p SuspendOnCriticalIncident) EventName() string { return "ReportedIncident" }

func (p SuspendOnCriticalIncident) Execute(event interface{}) {
	// trigger aggregate not found for SuspendModel
}
