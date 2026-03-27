package domain

// ClassifyAfterAssessment reacts to SubmittedAssessment
// and triggers ClassifyRisk

type ClassifyAfterAssessment struct {}

func (p ClassifyAfterAssessment) EventName() string { return "SubmittedAssessment" }

func (p ClassifyAfterAssessment) Execute(event interface{}) {
	// trigger aggregate not found for ClassifyRisk
}
