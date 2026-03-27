package domain

import "time"

type ApprovedVendor struct {
	AggregateID string    `json:"aggregate_id"`
	AggregateId string `json:"aggregate_id"`
	VendorId string `json:"vendor_id"`
	AssessmentDate time.Time `json:"assessment_date"`
	NextReviewDate time.Time `json:"next_review_date"`
	Name string `json:"name"`
	ContactEmail string `json:"contact_email"`
	RiskTier string `json:"risk_tier"`
	SlaTerms string `json:"sla_terms"`
	Status string `json:"status"`
	OccurredAt time.Time `json:"occurred_at"`
}

func (e ApprovedVendor) EventName() string { return "ApprovedVendor" }

func (e ApprovedVendor) GetOccurredAt() time.Time { return e.OccurredAt }
