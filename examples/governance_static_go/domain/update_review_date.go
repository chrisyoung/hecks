package domain

import (
	"time"
)

type UpdateReviewDate struct {
	PolicyId string `json:"policy_id"`
	ReviewDate time.Time `json:"review_date"`
}

func (c UpdateReviewDate) CommandName() string { return "UpdateReviewDate" }

func (c UpdateReviewDate) Execute(repo GovernancePolicyRepository) (*GovernancePolicy, *UpdatedReviewDate, error) {
	agg := NewGovernancePolicy("", "", "", "", time.Time{}, c.ReviewDate, nil, "")
	if err := agg.Validate(); err != nil {
		return nil, nil, err
	}
	if err := repo.Save(agg); err != nil {
		return nil, nil, err
	}
	event := UpdatedReviewDate{
		AggregateID: agg.ID,
		PolicyId: c.PolicyId,
		ReviewDate: c.ReviewDate,
		OccurredAt: time.Now(),
	}
	return agg, &event, nil
}
