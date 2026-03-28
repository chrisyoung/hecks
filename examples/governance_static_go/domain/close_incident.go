package domain

import (
	"time"
	"fmt"
)

type CloseIncident struct {
	IncidentId string `json:"incident_id"`
}

func (c CloseIncident) CommandName() string { return "CloseIncident" }

func (c CloseIncident) Execute(repo IncidentRepository) (*Incident, *ClosedIncident, error) {
	existing, err := repo.Find(c.IncidentId)
	if err != nil {
		return nil, nil, err
	}
	if existing == nil {
		return nil, nil, fmt.Errorf("Incident not found: %s", c.IncidentId)
	}
	if existing.Status != "resolved" {
		return nil, nil, fmt.Errorf("cannot CloseIncident: Incident is in %s state", existing.Status)
	}
	existing.Status = "closed"
	existing.UpdatedAt = time.Now()
	if err := existing.Validate(); err != nil {
		return nil, nil, err
	}
	if err := repo.Save(existing); err != nil {
		return nil, nil, err
	}
	event := ClosedIncident{
		AggregateID: existing.ID,
		IncidentId: c.IncidentId,
		OccurredAt: time.Now(),
	}
	return existing, &event, nil
}
