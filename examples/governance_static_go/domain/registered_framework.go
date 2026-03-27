package domain

import "time"

type RegisteredFramework struct {
	AggregateID string    `json:"aggregate_id"`
	AggregateId string `json:"aggregate_id"`
	Name string `json:"name"`
	Jurisdiction string `json:"jurisdiction"`
	Version string `json:"version"`
	Authority string `json:"authority"`
	EffectiveDate time.Time `json:"effective_date"`
	Requirements []FrameworkRequirement `json:"requirements"`
	Status string `json:"status"`
	OccurredAt time.Time `json:"occurred_at"`
}

func (e RegisteredFramework) EventName() string { return "RegisteredFramework" }

func (e RegisteredFramework) GetOccurredAt() time.Time { return e.OccurredAt }
