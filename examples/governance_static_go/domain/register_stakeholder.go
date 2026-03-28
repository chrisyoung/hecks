package domain

import (
	"time"
)

type RegisterStakeholder struct {
	Name string `json:"name"`
	Email string `json:"email"`
	Role string `json:"role"`
	Team string `json:"team"`
}

func (c RegisterStakeholder) CommandName() string { return "RegisterStakeholder" }

func (c RegisterStakeholder) Execute(repo StakeholderRepository) (*Stakeholder, *RegisteredStakeholder, error) {
	agg := NewStakeholder(c.Name, c.Email, c.Role, c.Team, "")
	agg.Status = "active"
	if err := agg.Validate(); err != nil {
		return nil, nil, err
	}
	if err := repo.Save(agg); err != nil {
		return nil, nil, err
	}
	event := RegisteredStakeholder{
		AggregateID: agg.ID,
		Name: c.Name,
		Email: c.Email,
		Role: c.Role,
		Team: c.Team,
		OccurredAt: time.Now(),
	}
	return agg, &event, nil
}
