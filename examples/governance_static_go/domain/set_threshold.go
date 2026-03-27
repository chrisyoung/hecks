package domain

import (
	"time"
	"fmt"
)

type SetThreshold struct {
	MonitoringId string `json:"monitoring_id"`
	Threshold float64 `json:"threshold"`
}

func (c SetThreshold) CommandName() string { return "SetThreshold" }

func (c SetThreshold) Execute(repo MonitoringRepository) (*Monitoring, *SetThresholdEvent, error) {
	existing, err := repo.Find(c.MonitoringId)
	if err != nil {
		return nil, nil, err
	}
	if existing == nil {
		return nil, nil, fmt.Errorf("Monitoring not found: %s", c.MonitoringId)
	}
	existing.Threshold = c.Threshold
	existing.UpdatedAt = time.Now()
	if err := existing.Validate(); err != nil {
		return nil, nil, err
	}
	if err := repo.Save(existing); err != nil {
		return nil, nil, err
	}
	event := SetThresholdEvent{
		AggregateID: existing.ID,
		MonitoringId: c.MonitoringId,
		Threshold: c.Threshold,
		OccurredAt: time.Now(),
	}
	return existing, &event, nil
}
