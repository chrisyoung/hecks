package domain

import "time"

type RejectedReview struct {
	AggregateID string    `json:"aggregate_id"`
	AggregateId string `json:"aggregate_id"`
	ReviewId string `json:"review_id"`
	Notes string `json:"notes"`
	ModelId string `json:"model_id"`
	PolicyId string `json:"policy_id"`
	ReviewerId string `json:"reviewer_id"`
	Outcome string `json:"outcome"`
	CompletedAt time.Time `json:"completed_at"`
	Conditions []ReviewCondition `json:"conditions"`
	Status string `json:"status"`
	OccurredAt time.Time `json:"occurred_at"`
}

func (e RejectedReview) EventName() string { return "RejectedReview" }

func (e RejectedReview) GetOccurredAt() time.Time { return e.OccurredAt }
