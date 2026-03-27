package domain

import (
	"time"
	"fmt"
)

type InvestigateIncident struct {
	IncidentId string `json:"incident_id"`
}

func (c InvestigateIncident) CommandName() string { return "InvestigateIncident" }

func (c InvestigateIncident) Execute(repo IncidentRepository) (*Incident, *InvestigatedIncident, error) {
	existing, err := repo.Find(c.IncidentId)
	if err != nil {
		return nil, nil, err
	}
	if existing == nil {
		return nil, nil, fmt.Errorf("Incident not found: %s", c.IncidentId)
	}
	existing.UpdatedAt = time.Now()
	if err := existing.Validate(); err != nil {
		return nil, nil, err
	}
	if err := repo.Save(existing); err != nil {
		return nil, nil, err
	}
	event := InvestigatedIncident{
		AggregateID: existing.ID,
		IncidentId: c.IncidentId,
		OccurredAt: time.Now(),
	}
	return existing, &event, nil
}
