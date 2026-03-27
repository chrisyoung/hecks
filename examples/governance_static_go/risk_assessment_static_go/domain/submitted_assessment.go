package domain

import "time"

type SubmittedAssessment struct {
	AggregateID string    `json:"aggregate_id"`
	AggregateId string `json:"aggregate_id"`
	AssessmentId string `json:"assessment_id"`
	RiskLevel string `json:"risk_level"`
	BiasScore float64 `json:"bias_score"`
	SafetyScore float64 `json:"safety_score"`
	TransparencyScore float64 `json:"transparency_score"`
	OverallScore float64 `json:"overall_score"`
	ModelId string `json:"model_id"`
	AssessorId string `json:"assessor_id"`
	SubmittedAt time.Time `json:"submitted_at"`
	Findings []Finding `json:"findings"`
	Mitigations []Mitigation `json:"mitigations"`
	Status string `json:"status"`
	OccurredAt time.Time `json:"occurred_at"`
}

func (e SubmittedAssessment) EventName() string { return "SubmittedAssessment" }

func (e SubmittedAssessment) GetOccurredAt() time.Time { return e.OccurredAt }
