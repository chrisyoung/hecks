package domain

import "time"

type SuspendedPolicy struct {
	AggregateID string    `json:"aggregate_id"`
	AggregateId string `json:"aggregate_id"`
	PolicyId string `json:"policy_id"`
	Name string `json:"name"`
	Description string `json:"description"`
	Category string `json:"category"`
	FrameworkId string `json:"framework_id"`
	EffectiveDate time.Time `json:"effective_date"`
	ReviewDate time.Time `json:"review_date"`
	Requirements []Requirement `json:"requirements"`
	Status string `json:"status"`
	OccurredAt time.Time `json:"occurred_at"`
}

func (e SuspendedPolicy) EventName() string { return "SuspendedPolicy" }

func (e SuspendedPolicy) GetOccurredAt() time.Time { return e.OccurredAt }
