package domain

// ClassifyAfterAssessment reacts to SubmittedAssessment
// and triggers ClassifyRisk

type ClassifyAfterAssessment struct {}

func (p ClassifyAfterAssessment) EventName() string { return "SubmittedAssessment" }

func (p ClassifyAfterAssessment) Execute(event interface{}, AiModelRepo AiModelRepository) error {
	e, ok := event.(*SubmittedAssessment)
	if !ok { return nil }
	cmd := ClassifyRisk{
		ModelId: e.ModelId,
		RiskLevel: e.RiskLevel,
	}
	_, _, err := cmd.Execute(AiModelRepo)
	return err
}
