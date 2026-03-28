package domain

import (
	"time"
)

type CreatePolicy struct {
	Name string `json:"name"`
	Description string `json:"description"`
	Category string `json:"category"`
	FrameworkId string `json:"framework_id"`
}

func (c CreatePolicy) CommandName() string { return "CreatePolicy" }

func (c CreatePolicy) Execute(repo GovernancePolicyRepository) (*GovernancePolicy, *CreatedPolicy, error) {
	agg := NewGovernancePolicy(c.Name, c.Description, c.Category, c.FrameworkId, time.Time{}, time.Time{}, nil, "")
	agg.Status = "draft"
	if err := agg.Validate(); err != nil {
		return nil, nil, err
	}
	if err := repo.Save(agg); err != nil {
		return nil, nil, err
	}
	event := CreatedPolicy{
		AggregateID: agg.ID,
		Name: c.Name,
		Description: c.Description,
		Category: c.Category,
		FrameworkId: c.FrameworkId,
		OccurredAt: time.Now(),
	}
	return agg, &event, nil
}
