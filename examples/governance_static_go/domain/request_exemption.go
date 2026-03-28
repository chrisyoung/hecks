package domain

import (
	"time"
)

type RequestExemption struct {
	ModelId string `json:"model_id"`
	PolicyId string `json:"policy_id"`
	Requirement string `json:"requirement"`
	Reason string `json:"reason"`
}

func (c RequestExemption) CommandName() string { return "RequestExemption" }

func (c RequestExemption) Execute(repo ExemptionRepository) (*Exemption, *RequestedExemption, error) {
	agg := NewExemption(c.ModelId, c.PolicyId, c.Requirement, c.Reason, "", time.Time{}, time.Time{}, "", "")
	agg.Status = "requested"
	if err := agg.Validate(); err != nil {
		return nil, nil, err
	}
	if err := repo.Save(agg); err != nil {
		return nil, nil, err
	}
	event := RequestedExemption{
		AggregateID: agg.ID,
		ModelId: c.ModelId,
		PolicyId: c.PolicyId,
		Requirement: c.Requirement,
		Reason: c.Reason,
		OccurredAt: time.Now(),
	}
	return agg, &event, nil
}
