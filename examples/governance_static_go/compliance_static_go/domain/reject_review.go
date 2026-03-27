package domain

import (
	"time"
)

type RejectReview struct {
	ReviewId string `json:"review_id"`
	Notes string `json:"notes"`
}

func (c RejectReview) CommandName() string { return "RejectReview" }

func (c RejectReview) Execute(repo ComplianceReviewRepository) (*ComplianceReview, *RejectedReview, error) {
	agg := NewComplianceReview("", "", "", "", c.Notes, time.Time{}, nil, "")
	if err := agg.Validate(); err != nil {
		return nil, nil, err
	}
	if err := repo.Save(agg); err != nil {
		return nil, nil, err
	}
	event := RejectedReview{
		AggregateID: agg.ID,
		ReviewId: c.ReviewId,
		Notes: c.Notes,
		OccurredAt: time.Now(),
	}
	return agg, &event, nil
}
