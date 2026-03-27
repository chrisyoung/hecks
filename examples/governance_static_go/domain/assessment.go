package domain

import (
	"time"
	"github.com/google/uuid"
)

type Assessment struct {
	ID        string    `json:"id"`
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
	CreatedAt time.Time `json:"created_at"`
	UpdatedAt time.Time `json:"updated_at"`
}

func NewAssessment(modelId string, assessorId string, riskLevel string, biasScore float64, safetyScore float64, transparencyScore float64, overallScore float64, submittedAt time.Time, findings []Finding, mitigations []Mitigation, status string) *Assessment {
	a := &Assessment{
		ID:        uuid.New().String(),
		ModelId: modelId,
		AssessorId: assessorId,
		RiskLevel: riskLevel,
		BiasScore: biasScore,
		SafetyScore: safetyScore,
		TransparencyScore: transparencyScore,
		OverallScore: overallScore,
		SubmittedAt: submittedAt,
		Findings: findings,
		Mitigations: mitigations,
		Status: status,
		CreatedAt: time.Now(),
		UpdatedAt: time.Now(),
	}
	return a
}

func (a *Assessment) Validate() error {
	return nil
}
