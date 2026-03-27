package domain

import (
	"time"
	"github.com/google/uuid"
)

type ComplianceReview struct {
	ID        string    `json:"id"`
	ModelId string `json:"model_id"`
	PolicyId string `json:"policy_id"`
	ReviewerId string `json:"reviewer_id"`
	Outcome string `json:"outcome"`
	Notes string `json:"notes"`
	CompletedAt time.Time `json:"completed_at"`
	Conditions []ReviewCondition `json:"conditions"`
	Status string `json:"status"`
	CreatedAt time.Time `json:"created_at"`
	UpdatedAt time.Time `json:"updated_at"`
}

func NewComplianceReview(modelId string, policyId string, reviewerId string, outcome string, notes string, completedAt time.Time, conditions []ReviewCondition, status string) *ComplianceReview {
	a := &ComplianceReview{
		ID:        uuid.New().String(),
		ModelId: modelId,
		PolicyId: policyId,
		ReviewerId: reviewerId,
		Outcome: outcome,
		Notes: notes,
		CompletedAt: completedAt,
		Conditions: conditions,
		Status: status,
		CreatedAt: time.Now(),
		UpdatedAt: time.Now(),
	}
	return a
}

func (a *ComplianceReview) Validate() error {
	return nil
}
