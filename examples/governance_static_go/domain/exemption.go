package domain

import (
	"time"
	"github.com/google/uuid"
)

type Exemption struct {
	ID string `json:"id"`
	CreatedAt time.Time `json:"created_at"`
	UpdatedAt time.Time `json:"updated_at"`
	ModelId string `json:"model_id"`
	PolicyId string `json:"policy_id"`
	Requirement string `json:"requirement"`
	Reason string `json:"reason"`
	ApprovedById string `json:"approved_by_id"`
	ApprovedAt time.Time `json:"approved_at"`
	ExpiresAt time.Time `json:"expires_at"`
	Scope string `json:"scope"`
	Status string `json:"status"`
}

func NewExemption(modelId string, policyId string, requirement string, reason string, approvedById string, approvedAt time.Time, expiresAt time.Time, scope string, status string) *Exemption {
	a := &Exemption{
		ID:        uuid.New().String(),
		ModelId: modelId,
		PolicyId: policyId,
		Requirement: requirement,
		Reason: reason,
		ApprovedById: approvedById,
		ApprovedAt: approvedAt,
		ExpiresAt: expiresAt,
		Scope: scope,
		Status: status,
		CreatedAt: time.Now(),
		UpdatedAt: time.Now(),
	}
	return a
}

func (a *Exemption) Validate() error {
	if a.ModelId == "" {
		return &ValidationError{Field: "model_id", Message: "model_id can't be blank"}
	}
	if a.PolicyId == "" {
		return &ValidationError{Field: "policy_id", Message: "policy_id can't be blank"}
	}
	return nil
}
