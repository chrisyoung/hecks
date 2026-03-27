package domain

import "time"

type RetiredFramework struct {
	AggregateID string    `json:"aggregate_id"`
	AggregateId string `json:"aggregate_id"`
	FrameworkId string `json:"framework_id"`
	Name string `json:"name"`
	Jurisdiction string `json:"jurisdiction"`
	Version string `json:"version"`
	EffectiveDate time.Time `json:"effective_date"`
	Authority string `json:"authority"`
	Requirements []FrameworkRequirement `json:"requirements"`
	Status string `json:"status"`
	OccurredAt time.Time `json:"occurred_at"`
}

func (e RetiredFramework) EventName() string { return "RetiredFramework" }

func (e RetiredFramework) GetOccurredAt() time.Time { return e.OccurredAt }
