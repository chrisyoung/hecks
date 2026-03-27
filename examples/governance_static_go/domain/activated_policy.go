package domain

import "time"

type ActivatedPolicy struct {
	AggregateID string    `json:"aggregate_id"`
	AggregateId string `json:"aggregate_id"`
	PolicyId string `json:"policy_id"`
	EffectiveDate time.Time `json:"effective_date"`
	Name string `json:"name"`
	Description string `json:"description"`
	Category string `json:"category"`
	FrameworkId string `json:"framework_id"`
	ReviewDate time.Time `json:"review_date"`
	Requirements []Requirement `json:"requirements"`
	Status string `json:"status"`
	OccurredAt time.Time `json:"occurred_at"`
}

func (e ActivatedPolicy) EventName() string { return "ActivatedPolicy" }

func (e ActivatedPolicy) GetOccurredAt() time.Time { return e.OccurredAt }
