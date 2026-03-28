package domain

import (
	"time"
	"github.com/google/uuid"
	"fmt"
)

type Assessment struct {
	ID string `json:"id"`
	CreatedAt time.Time `json:"created_at"`
	UpdatedAt time.Time `json:"updated_at"`
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
	if a.ModelId == "" {
		return &ValidationError{Field: "model_id", Message: "model_id can't be blank"}
	}
	if a.AssessorId == "" {
		return &ValidationError{Field: "assessor_id", Message: "assessor_id can't be blank"}
	}
	if a.RiskLevel != "" {
		validRiskLevel := map[string]bool{"low": true, "medium": true, "high": true, "critical": true}
		if !validRiskLevel[a.RiskLevel] {
			return &ValidationError{Field: "risk_level", Message: fmt.Sprintf("risk_level must be one of: low, medium, high, critical, got: %s", a.RiskLevel)}
		}
	}
	// invariant: scores must be between 0 and 1
	return nil
}
