package domain

import (
	"time"
	"fmt"
)

type RejectReview struct {
	ReviewId string `json:"review_id"`
	Notes string `json:"notes"`
}

func (c RejectReview) CommandName() string { return "RejectReview" }

func (c RejectReview) Execute(repo ComplianceReviewRepository) (*ComplianceReview, *RejectedReview, error) {
	existing, err := repo.Find(c.ReviewId)
	if err != nil {
		return nil, nil, err
	}
	if existing == nil {
		return nil, nil, fmt.Errorf("ComplianceReview not found: %s", c.ReviewId)
	}
	existing.Notes = c.Notes
	if existing.Status != "open" && existing.Status != "changes_requested" {
		return nil, nil, fmt.Errorf("cannot RejectReview: ComplianceReview is in %s state", existing.Status)
	}
	existing.Status = "rejected"
	existing.UpdatedAt = time.Now()
	if err := existing.Validate(); err != nil {
		return nil, nil, err
	}
	if err := repo.Save(existing); err != nil {
		return nil, nil, err
	}
	event := RejectedReview{
		AggregateID: existing.ID,
		ReviewId: c.ReviewId,
		Notes: c.Notes,
		OccurredAt: time.Now(),
	}
	return existing, &event, nil
}
