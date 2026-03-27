package domain

import (
	"time"
	"fmt"
)

type AssignRole struct {
	StakeholderId string `json:"stakeholder_id"`
	Role string `json:"role"`
}

func (c AssignRole) CommandName() string { return "AssignRole" }

func (c AssignRole) Execute(repo StakeholderRepository) (*Stakeholder, *AssignedRole, error) {
	existing, err := repo.Find(c.StakeholderId)
	if err != nil {
		return nil, nil, err
	}
	if existing == nil {
		return nil, nil, fmt.Errorf("Stakeholder not found: %s", c.StakeholderId)
	}
	existing.Role = c.Role
	existing.UpdatedAt = time.Now()
	if err := existing.Validate(); err != nil {
		return nil, nil, err
	}
	if err := repo.Save(existing); err != nil {
		return nil, nil, err
	}
	event := AssignedRole{
		AggregateID: existing.ID,
		StakeholderId: c.StakeholderId,
		Role: c.Role,
		OccurredAt: time.Now(),
	}
	return existing, &event, nil
}
