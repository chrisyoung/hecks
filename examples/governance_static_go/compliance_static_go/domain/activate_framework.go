package domain

import (
	"time"
)

type ActivateFramework struct {
	FrameworkId string `json:"framework_id"`
	EffectiveDate time.Time `json:"effective_date"`
}

func (c ActivateFramework) CommandName() string { return "ActivateFramework" }

func (c ActivateFramework) Execute(repo RegulatoryFrameworkRepository) (*RegulatoryFramework, *ActivatedFramework, error) {
	agg := NewRegulatoryFramework("", "", "", c.EffectiveDate, "", nil, "")
	if err := agg.Validate(); err != nil {
		return nil, nil, err
	}
	if err := repo.Save(agg); err != nil {
		return nil, nil, err
	}
	event := ActivatedFramework{
		AggregateID: agg.ID,
		FrameworkId: c.FrameworkId,
		EffectiveDate: c.EffectiveDate,
		OccurredAt: time.Now(),
	}
	return agg, &event, nil
}
