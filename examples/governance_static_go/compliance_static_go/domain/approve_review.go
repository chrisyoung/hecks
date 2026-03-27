package domain

import (
	"time"
)

type ApproveReview struct {
	ReviewId string `json:"review_id"`
	Notes string `json:"notes"`
}

func (c ApproveReview) CommandName() string { return "ApproveReview" }

func (c ApproveReview) Execute(repo ComplianceReviewRepository) (*ComplianceReview, *ApprovedReview, error) {
	agg := NewComplianceReview("", "", "", "", c.Notes, time.Time{}, nil, "")
	if err := agg.Validate(); err != nil {
		return nil, nil, err
	}
	if err := repo.Save(agg); err != nil {
		return nil, nil, err
	}
	event := ApprovedReview{
		AggregateID: agg.ID,
		ReviewId: c.ReviewId,
		Notes: c.Notes,
		OccurredAt: time.Now(),
	}
	return agg, &event, nil
}
