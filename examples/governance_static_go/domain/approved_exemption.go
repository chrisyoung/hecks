package domain

import "time"

type ApprovedExemption struct {
	AggregateID string    `json:"aggregate_id"`
	AggregateId string `json:"aggregate_id"`
	ExemptionId string `json:"exemption_id"`
	ApprovedById string `json:"approved_by_id"`
	ExpiresAt time.Time `json:"expires_at"`
	ModelId string `json:"model_id"`
	PolicyId string `json:"policy_id"`
	Requirement string `json:"requirement"`
	Reason string `json:"reason"`
	ApprovedAt time.Time `json:"approved_at"`
	Scope string `json:"scope"`
	Status string `json:"status"`
	OccurredAt time.Time `json:"occurred_at"`
}

func (e ApprovedExemption) EventName() string { return "ApprovedExemption" }

func (e ApprovedExemption) GetOccurredAt() time.Time { return e.OccurredAt }
