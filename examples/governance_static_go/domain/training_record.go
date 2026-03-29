package domain

import (
	"time"
	"github.com/google/uuid"
)

type TrainingRecord struct {
	ID string `json:"id"`
	CreatedAt time.Time `json:"created_at"`
	UpdatedAt time.Time `json:"updated_at"`
	StakeholderId string `json:"stakeholder_id"`
	PolicyId string `json:"policy_id"`
	CompletedAt time.Time `json:"completed_at"`
	ExpiresAt time.Time `json:"expires_at"`
	Certification string `json:"certification"`
	Status string `json:"status"`
}

func NewTrainingRecord(stakeholderId string, policyId string, completedAt time.Time, expiresAt time.Time, certification string, status string) *TrainingRecord {
	a := &TrainingRecord{
		ID:        uuid.New().String(),
		StakeholderId: stakeholderId,
		PolicyId: policyId,
		CompletedAt: completedAt,
		ExpiresAt: expiresAt,
		Certification: certification,
		Status: status,
		CreatedAt: time.Now(),
		UpdatedAt: time.Now(),
	}
	return a
}

func (a *TrainingRecord) Validate() error {
	if a.StakeholderId == "" {
		return &ValidationError{Field: "stakeholder_id", Message: "stakeholder_id can't be blank"}
	}
	if a.PolicyId == "" {
		return &ValidationError{Field: "policy_id", Message: "policy_id can't be blank"}
	}
	// invariant: expires_at must be after completed_at
	return nil
}
