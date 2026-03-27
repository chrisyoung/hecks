package domain

import (
	"time"
)

type ActivatePolicy struct {
	PolicyId string `json:"policy_id"`
	EffectiveDate time.Time `json:"effective_date"`
}

func (c ActivatePolicy) CommandName() string { return "ActivatePolicy" }

func (c ActivatePolicy) Execute(repo GovernancePolicyRepository) (*GovernancePolicy, *ActivatedPolicy, error) {
	agg := NewGovernancePolicy("", "", "", "", c.EffectiveDate, time.Time{}, nil, "")
	if err := agg.Validate(); err != nil {
		return nil, nil, err
	}
	if err := repo.Save(agg); err != nil {
		return nil, nil, err
	}
	event := ActivatedPolicy{
		AggregateID: agg.ID,
		PolicyId: c.PolicyId,
		EffectiveDate: c.EffectiveDate,
		OccurredAt: time.Now(),
	}
	return agg, &event, nil
}
