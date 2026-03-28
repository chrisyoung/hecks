package domain

import (
	"time"
	"fmt"
)

type ActivateFramework struct {
	FrameworkId string `json:"framework_id"`
	EffectiveDate time.Time `json:"effective_date"`
}

func (c ActivateFramework) CommandName() string { return "ActivateFramework" }

func (c ActivateFramework) Execute(repo RegulatoryFrameworkRepository) (*RegulatoryFramework, *ActivatedFramework, error) {
	existing, err := repo.Find(c.FrameworkId)
	if err != nil {
		return nil, nil, err
	}
	if existing == nil {
		return nil, nil, fmt.Errorf("RegulatoryFramework not found: %s", c.FrameworkId)
	}
	existing.EffectiveDate = c.EffectiveDate
	if existing.Status != "draft" {
		return nil, nil, fmt.Errorf("cannot ActivateFramework: RegulatoryFramework is in %s state", existing.Status)
	}
	existing.Status = "active"
	existing.UpdatedAt = time.Now()
	if err := existing.Validate(); err != nil {
		return nil, nil, err
	}
	if err := repo.Save(existing); err != nil {
		return nil, nil, err
	}
	event := ActivatedFramework{
		AggregateID: existing.ID,
		FrameworkId: c.FrameworkId,
		EffectiveDate: c.EffectiveDate,
		OccurredAt: time.Now(),
	}
	return existing, &event, nil
}
