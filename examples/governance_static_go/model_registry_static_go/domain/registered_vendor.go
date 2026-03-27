package domain

import "time"

type RegisteredVendor struct {
	AggregateID string    `json:"aggregate_id"`
	AggregateId string `json:"aggregate_id"`
	Name string `json:"name"`
	ContactEmail string `json:"contact_email"`
	RiskTier string `json:"risk_tier"`
	AssessmentDate time.Time `json:"assessment_date"`
	NextReviewDate time.Time `json:"next_review_date"`
	SlaTerms string `json:"sla_terms"`
	Status string `json:"status"`
	OccurredAt time.Time `json:"occurred_at"`
}

func (e RegisteredVendor) EventName() string { return "RegisteredVendor" }

func (e RegisteredVendor) GetOccurredAt() time.Time { return e.OccurredAt }
