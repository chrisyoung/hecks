package domain

import (
	"time"
	"fmt"
)

type ApproveExemption struct {
	ExemptionId string `json:"exemption_id"`
	ApprovedById string `json:"approved_by_id"`
	ExpiresAt time.Time `json:"expires_at"`
}

func (c ApproveExemption) CommandName() string { return "ApproveExemption" }

func (c ApproveExemption) Execute(repo ExemptionRepository) (*Exemption, *ApprovedExemption, error) {
	existing, err := repo.Find(c.ExemptionId)
	if err != nil {
		return nil, nil, err
	}
	if existing == nil {
		return nil, nil, fmt.Errorf("Exemption not found: %s", c.ExemptionId)
	}
	existing.ApprovedById = c.ApprovedById
	existing.ExpiresAt = c.ExpiresAt
	if existing.Status != "requested" {
		return nil, nil, fmt.Errorf("cannot ApproveExemption: Exemption is in %s state", existing.Status)
	}
	existing.Status = "active"
	existing.UpdatedAt = time.Now()
	if err := existing.Validate(); err != nil {
		return nil, nil, err
	}
	if err := repo.Save(existing); err != nil {
		return nil, nil, err
	}
	event := ApprovedExemption{
		AggregateID: existing.ID,
		ExemptionId: c.ExemptionId,
		ApprovedById: c.ApprovedById,
		ExpiresAt: c.ExpiresAt,
		OccurredAt: time.Now(),
	}
	return existing, &event, nil
}
