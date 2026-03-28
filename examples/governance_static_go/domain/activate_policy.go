package domain

import (
	"time"
	"fmt"
)

type ActivatePolicy struct {
	PolicyId string `json:"policy_id"`
	EffectiveDate time.Time `json:"effective_date"`
}

func (c ActivatePolicy) CommandName() string { return "ActivatePolicy" }

func (c ActivatePolicy) Execute(repo GovernancePolicyRepository) (*GovernancePolicy, *ActivatedPolicy, error) {
	existing, err := repo.Find(c.PolicyId)
	if err != nil {
		return nil, nil, err
	}
	if existing == nil {
		return nil, nil, fmt.Errorf("GovernancePolicy not found: %s", c.PolicyId)
	}
	existing.EffectiveDate = c.EffectiveDate
	if existing.Status != "draft" {
		return nil, nil, fmt.Errorf("cannot ActivatePolicy: GovernancePolicy is in %s state", existing.Status)
	}
	existing.Status = "active"
	existing.UpdatedAt = time.Now()
	if err := existing.Validate(); err != nil {
		return nil, nil, err
	}
	if err := repo.Save(existing); err != nil {
		return nil, nil, err
	}
	event := ActivatedPolicy{
		AggregateID: existing.ID,
		PolicyId: c.PolicyId,
		EffectiveDate: c.EffectiveDate,
		OccurredAt: time.Now(),
	}
	return existing, &event, nil
}
