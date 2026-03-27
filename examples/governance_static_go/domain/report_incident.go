package domain

import (
	"time"
)

type ReportIncident struct {
	ModelId string `json:"model_id"`
	Severity string `json:"severity"`
	Category string `json:"category"`
	Description string `json:"description"`
	ReportedById string `json:"reported_by_id"`
}

func (c ReportIncident) CommandName() string { return "ReportIncident" }

func (c ReportIncident) Execute(repo IncidentRepository) (*Incident, *ReportedIncident, error) {
	agg := NewIncident(c.ModelId, c.Severity, c.Category, c.Description, c.ReportedById, time.Time{}, time.Time{}, "", "", "")
	if err := agg.Validate(); err != nil {
		return nil, nil, err
	}
	if err := repo.Save(agg); err != nil {
		return nil, nil, err
	}
	event := ReportedIncident{
		AggregateID: agg.ID,
		ModelId: c.ModelId,
		Severity: c.Severity,
		Category: c.Category,
		Description: c.Description,
		ReportedById: c.ReportedById,
		OccurredAt: time.Now(),
	}
	return agg, &event, nil
}
