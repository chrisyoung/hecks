package domain

import "time"

type RevokedExemption struct {
	AggregateID string    `json:"aggregate_id"`
	AggregateId string `json:"aggregate_id"`
	ExemptionId string `json:"exemption_id"`
	ModelId string `json:"model_id"`
	PolicyId string `json:"policy_id"`
	Requirement string `json:"requirement"`
	Reason string `json:"reason"`
	ApprovedById string `json:"approved_by_id"`
	ApprovedAt time.Time `json:"approved_at"`
	ExpiresAt time.Time `json:"expires_at"`
	Scope string `json:"scope"`
	Status string `json:"status"`
	OccurredAt time.Time `json:"occurred_at"`
}

func (e RevokedExemption) EventName() string { return "RevokedExemption" }

func (e RevokedExemption) GetOccurredAt() time.Time { return e.OccurredAt }
