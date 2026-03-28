package domain

import (
	"time"
	"fmt"
)

type ApproveReview struct {
	ReviewId string `json:"review_id"`
	Notes string `json:"notes"`
}

func (c ApproveReview) CommandName() string { return "ApproveReview" }

func (c ApproveReview) Execute(repo ComplianceReviewRepository) (*ComplianceReview, *ApprovedReview, error) {
	existing, err := repo.Find(c.ReviewId)
	if err != nil {
		return nil, nil, err
	}
	if existing == nil {
		return nil, nil, fmt.Errorf("ComplianceReview not found: %s", c.ReviewId)
	}
	existing.Notes = c.Notes
	if existing.Status != "open" && existing.Status != "changes_requested" {
		return nil, nil, fmt.Errorf("cannot ApproveReview: ComplianceReview is in %s state", existing.Status)
	}
	existing.Status = "approved"
	existing.UpdatedAt = time.Now()
	if err := existing.Validate(); err != nil {
		return nil, nil, err
	}
	if err := repo.Save(existing); err != nil {
		return nil, nil, err
	}
	event := ApprovedReview{
		AggregateID: existing.ID,
		ReviewId: c.ReviewId,
		Notes: c.Notes,
		OccurredAt: time.Now(),
	}
	return existing, &event, nil
}
