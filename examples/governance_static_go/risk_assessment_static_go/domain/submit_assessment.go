package domain

import (
	"time"
	"fmt"
)

type SubmitAssessment struct {
	AssessmentId string `json:"assessment_id"`
	RiskLevel string `json:"risk_level"`
	BiasScore float64 `json:"bias_score"`
	SafetyScore float64 `json:"safety_score"`
	TransparencyScore float64 `json:"transparency_score"`
	OverallScore float64 `json:"overall_score"`
}

func (c SubmitAssessment) CommandName() string { return "SubmitAssessment" }

func (c SubmitAssessment) Execute(repo AssessmentRepository) (*Assessment, *SubmittedAssessment, error) {
	existing, err := repo.Find(c.AssessmentId)
	if err != nil {
		return nil, nil, err
	}
	if existing == nil {
		return nil, nil, fmt.Errorf("Assessment not found: %s", c.AssessmentId)
	}
	existing.RiskLevel = c.RiskLevel
	existing.BiasScore = c.BiasScore
	existing.SafetyScore = c.SafetyScore
	existing.TransparencyScore = c.TransparencyScore
	existing.OverallScore = c.OverallScore
	existing.UpdatedAt = time.Now()
	if err := existing.Validate(); err != nil {
		return nil, nil, err
	}
	if err := repo.Save(existing); err != nil {
		return nil, nil, err
	}
	event := SubmittedAssessment{
		AggregateID: existing.ID,
		AssessmentId: c.AssessmentId,
		RiskLevel: c.RiskLevel,
		BiasScore: c.BiasScore,
		SafetyScore: c.SafetyScore,
		TransparencyScore: c.TransparencyScore,
		OverallScore: c.OverallScore,
		OccurredAt: time.Now(),
	}
	return existing, &event, nil
}
