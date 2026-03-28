package domain

import (
	"time"
	"fmt"
)

type RevokeExemption struct {
	ExemptionId string `json:"exemption_id"`
}

func (c RevokeExemption) CommandName() string { return "RevokeExemption" }

func (c RevokeExemption) Execute(repo ExemptionRepository) (*Exemption, *RevokedExemption, error) {
	existing, err := repo.Find(c.ExemptionId)
	if err != nil {
		return nil, nil, err
	}
	if existing == nil {
		return nil, nil, fmt.Errorf("Exemption not found: %s", c.ExemptionId)
	}
	if existing.Status != "active" {
		return nil, nil, fmt.Errorf("cannot RevokeExemption: Exemption is in %s state", existing.Status)
	}
	existing.Status = "revoked"
	existing.UpdatedAt = time.Now()
	if err := existing.Validate(); err != nil {
		return nil, nil, err
	}
	if err := repo.Save(existing); err != nil {
		return nil, nil, err
	}
	event := RevokedExemption{
		AggregateID: existing.ID,
		ExemptionId: c.ExemptionId,
		OccurredAt: time.Now(),
	}
	return existing, &event, nil
}
