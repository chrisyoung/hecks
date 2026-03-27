package domain

import (
	"time"
)

type RetireFramework struct {
	FrameworkId string `json:"framework_id"`
}

func (c RetireFramework) CommandName() string { return "RetireFramework" }

func (c RetireFramework) Execute(repo RegulatoryFrameworkRepository) (*RegulatoryFramework, *RetiredFramework, error) {
	agg := NewRegulatoryFramework("", "", "", time.Time{}, "", nil, "")
	if err := agg.Validate(); err != nil {
		return nil, nil, err
	}
	if err := repo.Save(agg); err != nil {
		return nil, nil, err
	}
	event := RetiredFramework{
		AggregateID: agg.ID,
		FrameworkId: c.FrameworkId,
		OccurredAt: time.Now(),
	}
	return agg, &event, nil
}
