package domain

import (
	"time"
	"fmt"
)

type DeactivateStakeholder struct {
	StakeholderId string `json:"stakeholder_id"`
}

func (c DeactivateStakeholder) CommandName() string { return "DeactivateStakeholder" }

func (c DeactivateStakeholder) Execute(repo StakeholderRepository) (*Stakeholder, *DeactivatedStakeholder, error) {
	existing, err := repo.Find(c.StakeholderId)
	if err != nil {
		return nil, nil, err
	}
	if existing == nil {
		return nil, nil, fmt.Errorf("Stakeholder not found: %s", c.StakeholderId)
	}
	if existing.Status != "active" {
		return nil, nil, fmt.Errorf("cannot DeactivateStakeholder: Stakeholder is in %s state", existing.Status)
	}
	existing.Status = "deactivated"
	existing.UpdatedAt = time.Now()
	if err := existing.Validate(); err != nil {
		return nil, nil, err
	}
	if err := repo.Save(existing); err != nil {
		return nil, nil, err
	}
	event := DeactivatedStakeholder{
		AggregateID: existing.ID,
		StakeholderId: c.StakeholderId,
		OccurredAt: time.Now(),
	}
	return existing, &event, nil
}
