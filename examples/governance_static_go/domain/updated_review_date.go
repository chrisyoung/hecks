package domain

import "time"

type UpdatedReviewDate struct {
	AggregateID string    `json:"aggregate_id"`
	AggregateId string `json:"aggregate_id"`
	PolicyId string `json:"policy_id"`
	ReviewDate time.Time `json:"review_date"`
	Name string `json:"name"`
	Description string `json:"description"`
	Category string `json:"category"`
	FrameworkId string `json:"framework_id"`
	EffectiveDate time.Time `json:"effective_date"`
	Requirements []Requirement `json:"requirements"`
	Status string `json:"status"`
	OccurredAt time.Time `json:"occurred_at"`
}

func (e UpdatedReviewDate) EventName() string { return "UpdatedReviewDate" }

func (e UpdatedReviewDate) GetOccurredAt() time.Time { return e.OccurredAt }
