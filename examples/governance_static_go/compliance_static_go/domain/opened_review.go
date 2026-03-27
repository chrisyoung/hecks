package domain

import "time"

type OpenedReview struct {
	AggregateID string    `json:"aggregate_id"`
	AggregateId string `json:"aggregate_id"`
	ModelId string `json:"model_id"`
	PolicyId string `json:"policy_id"`
	ReviewerId string `json:"reviewer_id"`
	Outcome string `json:"outcome"`
	Notes string `json:"notes"`
	CompletedAt time.Time `json:"completed_at"`
	Conditions []ReviewCondition `json:"conditions"`
	Status string `json:"status"`
	OccurredAt time.Time `json:"occurred_at"`
}

func (e OpenedReview) EventName() string { return "OpenedReview" }

func (e OpenedReview) GetOccurredAt() time.Time { return e.OccurredAt }
