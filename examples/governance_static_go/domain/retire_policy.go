package domain

import (
	"time"
	"fmt"
)

type RetirePolicy struct {
	PolicyId string `json:"policy_id"`
}

func (c RetirePolicy) CommandName() string { return "RetirePolicy" }

func (c RetirePolicy) Execute(repo GovernancePolicyRepository) (*GovernancePolicy, *RetiredPolicy, error) {
	existing, err := repo.Find(c.PolicyId)
	if err != nil {
		return nil, nil, err
	}
	if existing == nil {
		return nil, nil, fmt.Errorf("GovernancePolicy not found: %s", c.PolicyId)
	}
	if existing.Status != "active" && existing.Status != "suspended" {
		return nil, nil, fmt.Errorf("cannot RetirePolicy: GovernancePolicy is in %s state", existing.Status)
	}
	existing.Status = "retired"
	existing.UpdatedAt = time.Now()
	if err := existing.Validate(); err != nil {
		return nil, nil, err
	}
	if err := repo.Save(existing); err != nil {
		return nil, nil, err
	}
	event := RetiredPolicy{
		AggregateID: existing.ID,
		PolicyId: c.PolicyId,
		OccurredAt: time.Now(),
	}
	return existing, &event, nil
}
