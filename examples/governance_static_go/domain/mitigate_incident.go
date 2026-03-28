package domain

import (
	"time"
	"fmt"
)

type MitigateIncident struct {
	IncidentId string `json:"incident_id"`
}

func (c MitigateIncident) CommandName() string { return "MitigateIncident" }

func (c MitigateIncident) Execute(repo IncidentRepository) (*Incident, *MitigatedIncident, error) {
	existing, err := repo.Find(c.IncidentId)
	if err != nil {
		return nil, nil, err
	}
	if existing == nil {
		return nil, nil, fmt.Errorf("Incident not found: %s", c.IncidentId)
	}
	if existing.Status != "investigating" {
		return nil, nil, fmt.Errorf("cannot MitigateIncident: Incident is in %s state", existing.Status)
	}
	existing.Status = "mitigating"
	existing.UpdatedAt = time.Now()
	if err := existing.Validate(); err != nil {
		return nil, nil, err
	}
	if err := repo.Save(existing); err != nil {
		return nil, nil, err
	}
	event := MitigatedIncident{
		AggregateID: existing.ID,
		IncidentId: c.IncidentId,
		OccurredAt: time.Now(),
	}
	return existing, &event, nil
}
