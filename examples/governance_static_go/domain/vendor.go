package domain

import (
	"time"
	"github.com/google/uuid"
)

type Vendor struct {
	ID        string    `json:"id"`
	Name string `json:"name"`
	ContactEmail string `json:"contact_email"`
	RiskTier string `json:"risk_tier"`
	AssessmentDate time.Time `json:"assessment_date"`
	NextReviewDate time.Time `json:"next_review_date"`
	SlaTerms string `json:"sla_terms"`
	Status string `json:"status"`
	CreatedAt time.Time `json:"created_at"`
	UpdatedAt time.Time `json:"updated_at"`
}

func NewVendor(name string, contactEmail string, riskTier string, assessmentDate time.Time, nextReviewDate time.Time, slaTerms string, status string) *Vendor {
	a := &Vendor{
		ID:        uuid.New().String(),
		Name: name,
		ContactEmail: contactEmail,
		RiskTier: riskTier,
		AssessmentDate: assessmentDate,
		NextReviewDate: nextReviewDate,
		SlaTerms: slaTerms,
		Status: status,
		CreatedAt: time.Now(),
		UpdatedAt: time.Now(),
	}
	return a
}

func (a *Vendor) Validate() error {
	return nil
}
