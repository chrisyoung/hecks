package domain

import (
	"time"
	"fmt"
)

type UpdateReviewDate struct {
	PolicyId string `json:"policy_id"`
	ReviewDate time.Time `json:"review_date"`
}

func (c UpdateReviewDate) CommandName() string { return "UpdateReviewDate" }

func (c UpdateReviewDate) Execute(repo GovernancePolicyRepository) (*GovernancePolicy, *UpdatedReviewDate, error) {
	existing, err := repo.Find(c.PolicyId)
	if err != nil {
		return nil, nil, err
	}
	if existing == nil {
		return nil, nil, fmt.Errorf("GovernancePolicy not found: %s", c.PolicyId)
	}
	existing.ReviewDate = c.ReviewDate
	existing.UpdatedAt = time.Now()
	if err := existing.Validate(); err != nil {
		return nil, nil, err
	}
	if err := repo.Save(existing); err != nil {
		return nil, nil, err
	}
	event := UpdatedReviewDate{
		AggregateID: existing.ID,
		PolicyId: c.PolicyId,
		ReviewDate: c.ReviewDate,
		OccurredAt: time.Now(),
	}
	return existing, &event, nil
}
