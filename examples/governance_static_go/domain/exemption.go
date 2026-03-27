package domain

import (
	"time"
	"github.com/google/uuid"
)

type Exemption struct {
	ID        string    `json:"id"`
	ModelId string `json:"model_id"`
	PolicyId string `json:"policy_id"`
	Requirement string `json:"requirement"`
	Reason string `json:"reason"`
	ApprovedById string `json:"approved_by_id"`
	ApprovedAt time.Time `json:"approved_at"`
	ExpiresAt time.Time `json:"expires_at"`
	Status string `json:"status"`
	CreatedAt time.Time `json:"created_at"`
	UpdatedAt time.Time `json:"updated_at"`
}

func NewExemption(modelId string, policyId string, requirement string, reason string, approvedById string, approvedAt time.Time, expiresAt time.Time, status string) *Exemption {
	a := &Exemption{
		ID:        uuid.New().String(),
		ModelId: modelId,
		PolicyId: policyId,
		Requirement: requirement,
		Reason: reason,
		ApprovedById: approvedById,
		ApprovedAt: approvedAt,
		ExpiresAt: expiresAt,
		Status: status,
		CreatedAt: time.Now(),
		UpdatedAt: time.Now(),
	}
	return a
}

func (a *Exemption) Validate() error {
	return nil
}
