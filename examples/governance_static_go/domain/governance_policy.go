package domain

import (
	"time"
	"github.com/google/uuid"
)

type GovernancePolicy struct {
	ID        string    `json:"id"`
	Name string `json:"name"`
	Description string `json:"description"`
	Category string `json:"category"`
	FrameworkId string `json:"framework_id"`
	EffectiveDate time.Time `json:"effective_date"`
	ReviewDate time.Time `json:"review_date"`
	Requirements []Requirement `json:"requirements"`
	Status string `json:"status"`
	CreatedAt time.Time `json:"created_at"`
	UpdatedAt time.Time `json:"updated_at"`
}

func NewGovernancePolicy(name string, description string, category string, frameworkId string, effectiveDate time.Time, reviewDate time.Time, requirements []Requirement, status string) *GovernancePolicy {
	a := &GovernancePolicy{
		ID:        uuid.New().String(),
		Name: name,
		Description: description,
		Category: category,
		FrameworkId: frameworkId,
		EffectiveDate: effectiveDate,
		ReviewDate: reviewDate,
		Requirements: requirements,
		Status: status,
		CreatedAt: time.Now(),
		UpdatedAt: time.Now(),
	}
	return a
}

func (a *GovernancePolicy) Validate() error {
	if a.Name == "" {
		return &ValidationError{Field: "name", Message: "name can't be blank"}
	}
	if a.Category == "" {
		return &ValidationError{Field: "category", Message: "category can't be blank"}
	}
	return nil
}
