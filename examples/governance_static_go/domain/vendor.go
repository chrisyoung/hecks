package domain

import (
	"time"
	"github.com/google/uuid"
	"fmt"
)

type Vendor struct {
	ID string `json:"id"`
	CreatedAt time.Time `json:"created_at"`
	UpdatedAt time.Time `json:"updated_at"`
	Name string `json:"name"`
	ContactEmail string `json:"contact_email"`
	RiskTier string `json:"risk_tier"`
	AssessmentDate time.Time `json:"assessment_date"`
	NextReviewDate time.Time `json:"next_review_date"`
	SlaTerms string `json:"sla_terms"`
	Status string `json:"status"`
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
	if a.Name == "" {
		return &ValidationError{Field: "name", Message: "name can't be blank"}
	}
	if a.RiskTier != "" {
		validRiskTier := map[string]bool{"low": true, "medium": true, "high": true}
		if !validRiskTier[a.RiskTier] {
			return &ValidationError{Field: "risk_tier", Message: fmt.Sprintf("risk_tier must be one of: low, medium, high, got: %s", a.RiskTier)}
		}
	}
	return nil
}
