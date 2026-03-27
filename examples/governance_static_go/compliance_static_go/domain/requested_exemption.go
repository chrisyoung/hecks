package domain

import "time"

type RequestedExemption struct {
	AggregateID string    `json:"aggregate_id"`
	AggregateId string `json:"aggregate_id"`
	ModelId string `json:"model_id"`
	PolicyId string `json:"policy_id"`
	Requirement string `json:"requirement"`
	Reason string `json:"reason"`
	ApprovedById string `json:"approved_by_id"`
	ApprovedAt time.Time `json:"approved_at"`
	ExpiresAt time.Time `json:"expires_at"`
	Status string `json:"status"`
	OccurredAt time.Time `json:"occurred_at"`
}

func (e RequestedExemption) EventName() string { return "RequestedExemption" }

func (e RequestedExemption) GetOccurredAt() time.Time { return e.OccurredAt }
