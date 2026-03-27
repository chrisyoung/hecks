package domain

import "time"

type MitigatedIncident struct {
	AggregateID string    `json:"aggregate_id"`
	AggregateId string `json:"aggregate_id"`
	IncidentId string `json:"incident_id"`
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
	OccurredAt time.Time `json:"occurred_at"`
}

func (e MitigatedIncident) EventName() string { return "MitigatedIncident" }

func (e MitigatedIncident) GetOccurredAt() time.Time { return e.OccurredAt }
