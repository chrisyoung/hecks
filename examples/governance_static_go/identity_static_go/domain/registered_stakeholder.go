package domain

import "time"

type RegisteredStakeholder struct {
	AggregateID string    `json:"aggregate_id"`
	AggregateId string `json:"aggregate_id"`
	Name string `json:"name"`
	Email string `json:"email"`
	Role string `json:"role"`
	Team string `json:"team"`
	Status string `json:"status"`
	OccurredAt time.Time `json:"occurred_at"`
}

func (e RegisteredStakeholder) EventName() string { return "RegisteredStakeholder" }

func (e RegisteredStakeholder) GetOccurredAt() time.Time { return e.OccurredAt }
