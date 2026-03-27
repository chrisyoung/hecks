package domain

import "time"

type RecordedFinding struct {
	AggregateID string    `json:"aggregate_id"`
	AggregateId string `json:"aggregate_id"`
	AssessmentId string `json:"assessment_id"`
	Category string `json:"category"`
	Severity string `json:"severity"`
	Description string `json:"description"`
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

func (e RecordedFinding) EventName() string { return "RecordedFinding" }

func (e RecordedFinding) GetOccurredAt() time.Time { return e.OccurredAt }
