package domain

import (
	"time"
)

type OpenReview struct {
	ModelId string `json:"model_id"`
	PolicyId string `json:"policy_id"`
	ReviewerId string `json:"reviewer_id"`
}

func (c OpenReview) CommandName() string { return "OpenReview" }

func (c OpenReview) Execute(repo ComplianceReviewRepository) (*ComplianceReview, *OpenedReview, error) {
	agg := NewComplianceReview(c.ModelId, c.PolicyId, c.ReviewerId, "", "", time.Time{}, nil, "")
	agg.Status = "open"
	if err := agg.Validate(); err != nil {
		return nil, nil, err
	}
	if err := repo.Save(agg); err != nil {
		return nil, nil, err
	}
	event := OpenedReview{
		AggregateID: agg.ID,
		ModelId: c.ModelId,
		PolicyId: c.PolicyId,
		ReviewerId: c.ReviewerId,
		OccurredAt: time.Now(),
	}
	return agg, &event, nil
}
