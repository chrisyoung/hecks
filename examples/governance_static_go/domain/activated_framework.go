package domain

import "time"

type ActivatedFramework struct {
	AggregateID string    `json:"aggregate_id"`
	AggregateId string `json:"aggregate_id"`
	FrameworkId string `json:"framework_id"`
	EffectiveDate time.Time `json:"effective_date"`
	Name string `json:"name"`
	Jurisdiction string `json:"jurisdiction"`
	Version string `json:"version"`
	Authority string `json:"authority"`
	Requirements []FrameworkRequirement `json:"requirements"`
	Status string `json:"status"`
	OccurredAt time.Time `json:"occurred_at"`
}

func (e ActivatedFramework) EventName() string { return "ActivatedFramework" }

func (e ActivatedFramework) GetOccurredAt() time.Time { return e.OccurredAt }
