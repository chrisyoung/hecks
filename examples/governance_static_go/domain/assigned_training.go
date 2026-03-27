package domain

import "time"

type AssignedTraining struct {
	AggregateID string    `json:"aggregate_id"`
	AggregateId string `json:"aggregate_id"`
	StakeholderId string `json:"stakeholder_id"`
	PolicyId string `json:"policy_id"`
	CompletedAt time.Time `json:"completed_at"`
	ExpiresAt time.Time `json:"expires_at"`
	CertificationId string `json:"certification_id"`
	Status string `json:"status"`
	OccurredAt time.Time `json:"occurred_at"`
}

func (e AssignedTraining) EventName() string { return "AssignedTraining" }

func (e AssignedTraining) GetOccurredAt() time.Time { return e.OccurredAt }
