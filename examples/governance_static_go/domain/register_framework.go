package domain

import (
	"time"
)

type RegisterFramework struct {
	Name string `json:"name"`
	Jurisdiction string `json:"jurisdiction"`
	Version string `json:"version"`
	Authority string `json:"authority"`
}

func (c RegisterFramework) CommandName() string { return "RegisterFramework" }

func (c RegisterFramework) Execute(repo RegulatoryFrameworkRepository) (*RegulatoryFramework, *RegisteredFramework, error) {
	agg := NewRegulatoryFramework(c.Name, c.Jurisdiction, c.Version, time.Time{}, c.Authority, nil, "")
	if err := agg.Validate(); err != nil {
		return nil, nil, err
	}
	if err := repo.Save(agg); err != nil {
		return nil, nil, err
	}
	event := RegisteredFramework{
		AggregateID: agg.ID,
		Name: c.Name,
		Jurisdiction: c.Jurisdiction,
		Version: c.Version,
		Authority: c.Authority,
		OccurredAt: time.Now(),
	}
	return agg, &event, nil
}
