package domain

import (
	"time"
	"fmt"
)

type RetireFramework struct {
	FrameworkId string `json:"framework_id"`
}

func (c RetireFramework) CommandName() string { return "RetireFramework" }

func (c RetireFramework) Execute(repo RegulatoryFrameworkRepository) (*RegulatoryFramework, *RetiredFramework, error) {
	existing, err := repo.Find(c.FrameworkId)
	if err != nil {
		return nil, nil, err
	}
	if existing == nil {
		return nil, nil, fmt.Errorf("RegulatoryFramework not found: %s", c.FrameworkId)
	}
	if existing.Status != "active" {
		return nil, nil, fmt.Errorf("cannot RetireFramework: RegulatoryFramework is in %s state", existing.Status)
	}
	existing.Status = "retired"
	existing.UpdatedAt = time.Now()
	if err := existing.Validate(); err != nil {
		return nil, nil, err
	}
	if err := repo.Save(existing); err != nil {
		return nil, nil, err
	}
	event := RetiredFramework{
		AggregateID: existing.ID,
		FrameworkId: c.FrameworkId,
		OccurredAt: time.Now(),
	}
	return existing, &event, nil
}
