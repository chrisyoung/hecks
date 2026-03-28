package domain

import (
	"time"
	"fmt"
)

type RequestChanges struct {
	ReviewId string `json:"review_id"`
	Notes string `json:"notes"`
}

func (c RequestChanges) CommandName() string { return "RequestChanges" }

func (c RequestChanges) Execute(repo ComplianceReviewRepository) (*ComplianceReview, *RequestedChanges, error) {
	existing, err := repo.Find(c.ReviewId)
	if err != nil {
		return nil, nil, err
	}
	if existing == nil {
		return nil, nil, fmt.Errorf("ComplianceReview not found: %s", c.ReviewId)
	}
	existing.Notes = c.Notes
	if existing.Status != "open" {
		return nil, nil, fmt.Errorf("cannot RequestChanges: ComplianceReview is in %s state", existing.Status)
	}
	existing.Status = "changes_requested"
	existing.UpdatedAt = time.Now()
	if err := existing.Validate(); err != nil {
		return nil, nil, err
	}
	if err := repo.Save(existing); err != nil {
		return nil, nil, err
	}
	event := RequestedChanges{
		AggregateID: existing.ID,
		ReviewId: c.ReviewId,
		Notes: c.Notes,
		OccurredAt: time.Now(),
	}
	return existing, &event, nil
}
