package domain

import "time"

type AssignedRole struct {
	AggregateID string    `json:"aggregate_id"`
	AggregateId string `json:"aggregate_id"`
	StakeholderId string `json:"stakeholder_id"`
	Role string `json:"role"`
	Name string `json:"name"`
	Email string `json:"email"`
	Team string `json:"team"`
	Status string `json:"status"`
	OccurredAt time.Time `json:"occurred_at"`
}

func (e AssignedRole) EventName() string { return "AssignedRole" }

func (e AssignedRole) GetOccurredAt() time.Time { return e.OccurredAt }
