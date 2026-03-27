package domain

import "time"

type InitiatedAssessment struct {
	AggregateID string    `json:"aggregate_id"`
	AggregateId string `json:"aggregate_id"`
	ModelId string `json:"model_id"`
	AssessorId string `json:"assessor_id"`
	RiskLevel string `json:"risk_level"`
	BiasScore float64 `json:"bias_score"`
	SafetyScore float64 `json:"safety_score"`
	TransparencyScore float64 `json:"transparency_score"`
	OverallScore float64 `json:"overall_score"`
	SubmittedAt time.Time `json:"submitted_at"`
	Findings []Finding `json:"findings"`
	Mitigations []Mitigation `json:"mitigations"`
	Status string `json:"status"`
	OccurredAt time.Time `json:"occurred_at"`
}

func (e InitiatedAssessment) EventName() string { return "InitiatedAssessment" }

func (e InitiatedAssessment) GetOccurredAt() time.Time { return e.OccurredAt }
