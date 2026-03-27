package domain

import (
	"time"
)

type SuspendPolicy struct {
	PolicyId string `json:"policy_id"`
}

func (c SuspendPolicy) CommandName() string { return "SuspendPolicy" }

func (c SuspendPolicy) Execute(repo GovernancePolicyRepository) (*GovernancePolicy, *SuspendedPolicy, error) {
	agg := NewGovernancePolicy("", "", "", "", time.Time{}, time.Time{}, nil, "")
	if err := agg.Validate(); err != nil {
		return nil, nil, err
	}
	if err := repo.Save(agg); err != nil {
		return nil, nil, err
	}
	event := SuspendedPolicy{
		AggregateID: agg.ID,
		PolicyId: c.PolicyId,
		OccurredAt: time.Now(),
	}
	return agg, &event, nil
}
