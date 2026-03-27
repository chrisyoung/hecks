package domain

import (
	"time"
)

type RetirePolicy struct {
	PolicyId string `json:"policy_id"`
}

func (c RetirePolicy) CommandName() string { return "RetirePolicy" }

func (c RetirePolicy) Execute(repo GovernancePolicyRepository) (*GovernancePolicy, *RetiredPolicy, error) {
	agg := NewGovernancePolicy("", "", "", "", time.Time{}, time.Time{}, nil, "")
	if err := agg.Validate(); err != nil {
		return nil, nil, err
	}
	if err := repo.Save(agg); err != nil {
		return nil, nil, err
	}
	event := RetiredPolicy{
		AggregateID: agg.ID,
		PolicyId: c.PolicyId,
		OccurredAt: time.Now(),
	}
	return agg, &event, nil
}
