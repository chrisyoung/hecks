package domain

import "time"

type DeactivatedStakeholder struct {
	AggregateID string    `json:"aggregate_id"`
	AggregateId string `json:"aggregate_id"`
	StakeholderId string `json:"stakeholder_id"`
	Name string `json:"name"`
	Email string `json:"email"`
	Role string `json:"role"`
	Team string `json:"team"`
	Status string `json:"status"`
	OccurredAt time.Time `json:"occurred_at"`
}

func (e DeactivatedStakeholder) EventName() string { return "DeactivatedStakeholder" }

func (e DeactivatedStakeholder) GetOccurredAt() time.Time { return e.OccurredAt }
