package domain

import "time"

type RenewedTraining struct {
	AggregateID string    `json:"aggregate_id"`
	AggregateId string `json:"aggregate_id"`
	TrainingRecordId string `json:"training_record_id"`
	Certification string `json:"certification"`
	ExpiresAt time.Time `json:"expires_at"`
	StakeholderId string `json:"stakeholder_id"`
	PolicyId string `json:"policy_id"`
	CompletedAt time.Time `json:"completed_at"`
	Status string `json:"status"`
	OccurredAt time.Time `json:"occurred_at"`
}

func (e RenewedTraining) EventName() string { return "RenewedTraining" }

func (e RenewedTraining) GetOccurredAt() time.Time { return e.OccurredAt }
