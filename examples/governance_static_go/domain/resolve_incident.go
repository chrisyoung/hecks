package domain

import (
	"time"
	"fmt"
)

type ResolveIncident struct {
	IncidentId string `json:"incident_id"`
	Resolution string `json:"resolution"`
	RootCause string `json:"root_cause"`
}

func (c ResolveIncident) CommandName() string { return "ResolveIncident" }

func (c ResolveIncident) Execute(repo IncidentRepository) (*Incident, *ResolvedIncident, error) {
	existing, err := repo.Find(c.IncidentId)
	if err != nil {
		return nil, nil, err
	}
	if existing == nil {
		return nil, nil, fmt.Errorf("Incident not found: %s", c.IncidentId)
	}
	existing.Resolution = c.Resolution
	existing.RootCause = c.RootCause
	if existing.Status != "investigating" && existing.Status != "mitigating" {
		return nil, nil, fmt.Errorf("cannot ResolveIncident: Incident is in %s state", existing.Status)
	}
	existing.Status = "resolved"
	existing.UpdatedAt = time.Now()
	if err := existing.Validate(); err != nil {
		return nil, nil, err
	}
	if err := repo.Save(existing); err != nil {
		return nil, nil, err
	}
	event := ResolvedIncident{
		AggregateID: existing.ID,
		IncidentId: c.IncidentId,
		Resolution: c.Resolution,
		RootCause: c.RootCause,
		OccurredAt: time.Now(),
	}
	return existing, &event, nil
}
