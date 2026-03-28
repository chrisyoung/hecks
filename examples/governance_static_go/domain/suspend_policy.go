package domain

import (
	"time"
	"fmt"
)

type SuspendPolicy struct {
	PolicyId string `json:"policy_id"`
}

func (c SuspendPolicy) CommandName() string { return "SuspendPolicy" }

func (c SuspendPolicy) Execute(repo GovernancePolicyRepository) (*GovernancePolicy, *SuspendedPolicy, error) {
	existing, err := repo.Find(c.PolicyId)
	if err != nil {
		return nil, nil, err
	}
	if existing == nil {
		return nil, nil, fmt.Errorf("GovernancePolicy not found: %s", c.PolicyId)
	}
	if existing.Status != "active" {
		return nil, nil, fmt.Errorf("cannot SuspendPolicy: GovernancePolicy is in %s state", existing.Status)
	}
	existing.Status = "suspended"
	existing.UpdatedAt = time.Now()
	if err := existing.Validate(); err != nil {
		return nil, nil, err
	}
	if err := repo.Save(existing); err != nil {
		return nil, nil, err
	}
	event := SuspendedPolicy{
		AggregateID: existing.ID,
		PolicyId: c.PolicyId,
		OccurredAt: time.Now(),
	}
	return existing, &event, nil
}
