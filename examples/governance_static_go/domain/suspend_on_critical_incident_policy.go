package domain

// SuspendOnCriticalIncident reacts to ReportedIncident
// and triggers SuspendModel

type SuspendOnCriticalIncident struct {}

func (p SuspendOnCriticalIncident) EventName() string { return "ReportedIncident" }

func (p SuspendOnCriticalIncident) Execute(event interface{}, AiModelRepo AiModelRepository) error {
	e, ok := event.(*ReportedIncident)
	if !ok { return nil }
	cmd := SuspendModel{
		ModelId: e.ModelId,
	}
	_, _, err := cmd.Execute(AiModelRepo)
	return err
}
