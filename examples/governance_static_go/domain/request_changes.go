package domain

import (
	"time"
)

type RequestChanges struct {
	ReviewId string `json:"review_id"`
	Notes string `json:"notes"`
}

func (c RequestChanges) CommandName() string { return "RequestChanges" }

func (c RequestChanges) Execute(repo ComplianceReviewRepository) (*ComplianceReview, *RequestedChanges, error) {
	agg := NewComplianceReview("", "", "", "", c.Notes, time.Time{}, nil, "")
	if err := agg.Validate(); err != nil {
		return nil, nil, err
	}
	if err := repo.Save(agg); err != nil {
		return nil, nil, err
	}
	event := RequestedChanges{
		AggregateID: agg.ID,
		ReviewId: c.ReviewId,
		Notes: c.Notes,
		OccurredAt: time.Now(),
	}
	return agg, &event, nil
}
