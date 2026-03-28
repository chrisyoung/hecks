package domain

import (
	"time"
	"github.com/google/uuid"
	"fmt"
)

type Incident struct {
	ID string `json:"id"`
	CreatedAt time.Time `json:"created_at"`
	UpdatedAt time.Time `json:"updated_at"`
	ModelId string `json:"model_id"`
	Severity string `json:"severity"`
	Category string `json:"category"`
	Description string `json:"description"`
	ReportedById string `json:"reported_by_id"`
	ReportedAt time.Time `json:"reported_at"`
	ResolvedAt time.Time `json:"resolved_at"`
	Resolution string `json:"resolution"`
	RootCause string `json:"root_cause"`
	Status string `json:"status"`
}

func NewIncident(modelId string, severity string, category string, description string, reportedById string, reportedAt time.Time, resolvedAt time.Time, resolution string, rootCause string, status string) *Incident {
	a := &Incident{
		ID:        uuid.New().String(),
		ModelId: modelId,
		Severity: severity,
		Category: category,
		Description: description,
		ReportedById: reportedById,
		ReportedAt: reportedAt,
		ResolvedAt: resolvedAt,
		Resolution: resolution,
		RootCause: rootCause,
		Status: status,
		CreatedAt: time.Now(),
		UpdatedAt: time.Now(),
	}
	return a
}

func (a *Incident) Validate() error {
	if a.ModelId == "" {
		return &ValidationError{Field: "model_id", Message: "model_id can't be blank"}
	}
	if a.Severity == "" {
		return &ValidationError{Field: "severity", Message: "severity can't be blank"}
	}
	if a.Severity != "" {
		validSeverity := map[string]bool{"low": true, "medium": true, "high": true, "critical": true}
		if !validSeverity[a.Severity] {
			return &ValidationError{Field: "severity", Message: fmt.Sprintf("severity must be one of: low, medium, high, critical, got: %s", a.Severity)}
		}
	}
	if a.Category != "" {
		validCategory := map[string]bool{"bias": true, "safety": true, "privacy": true, "performance": true, "other": true}
		if !validCategory[a.Category] {
			return &ValidationError{Field: "category", Message: fmt.Sprintf("category must be one of: bias, safety, privacy, performance, other, got: %s", a.Category)}
		}
	}
	return nil
}
