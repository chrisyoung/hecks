package domain

import (
	"time"
	"github.com/google/uuid"
)

type RegulatoryFramework struct {
	ID        string    `json:"id"`
	Name string `json:"name"`
	Jurisdiction string `json:"jurisdiction"`
	Version string `json:"version"`
	EffectiveDate time.Time `json:"effective_date"`
	Authority string `json:"authority"`
	Requirements []FrameworkRequirement `json:"requirements"`
	Status string `json:"status"`
	CreatedAt time.Time `json:"created_at"`
	UpdatedAt time.Time `json:"updated_at"`
}

func NewRegulatoryFramework(name string, jurisdiction string, version string, effectiveDate time.Time, authority string, requirements []FrameworkRequirement, status string) *RegulatoryFramework {
	a := &RegulatoryFramework{
		ID:        uuid.New().String(),
		Name: name,
		Jurisdiction: jurisdiction,
		Version: version,
		EffectiveDate: effectiveDate,
		Authority: authority,
		Requirements: requirements,
		Status: status,
		CreatedAt: time.Now(),
		UpdatedAt: time.Now(),
	}
	return a
}

func (a *RegulatoryFramework) Validate() error {
	if a.Name == "" {
		return &ValidationError{Field: "name", Message: "name can't be blank"}
	}
	if a.Jurisdiction == "" {
		return &ValidationError{Field: "jurisdiction", Message: "jurisdiction can't be blank"}
	}
	return nil
}
