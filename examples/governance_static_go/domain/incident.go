package domain

import (
	"time"
	"github.com/google/uuid"
)

type Incident struct {
	ID        string    `json:"id"`
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
	CreatedAt time.Time `json:"created_at"`
	UpdatedAt time.Time `json:"updated_at"`
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
	return nil
}
