package domain

import (
	"time"
	"fmt"
)

type ApproveVendor struct {
	VendorId string `json:"vendor_id"`
	AssessmentDate time.Time `json:"assessment_date"`
	NextReviewDate time.Time `json:"next_review_date"`
}

func (c ApproveVendor) CommandName() string { return "ApproveVendor" }

func (c ApproveVendor) Execute(repo VendorRepository) (*Vendor, *ApprovedVendor, error) {
	existing, err := repo.Find(c.VendorId)
	if err != nil {
		return nil, nil, err
	}
	if existing == nil {
		return nil, nil, fmt.Errorf("Vendor not found: %s", c.VendorId)
	}
	existing.AssessmentDate = c.AssessmentDate
	existing.NextReviewDate = c.NextReviewDate
	if existing.Status != "pending_review" {
		return nil, nil, fmt.Errorf("cannot ApproveVendor: Vendor is in %s state", existing.Status)
	}
	existing.Status = "approved"
	existing.UpdatedAt = time.Now()
	if err := existing.Validate(); err != nil {
		return nil, nil, err
	}
	if err := repo.Save(existing); err != nil {
		return nil, nil, err
	}
	event := ApprovedVendor{
		AggregateID: existing.ID,
		VendorId: c.VendorId,
		AssessmentDate: c.AssessmentDate,
		NextReviewDate: c.NextReviewDate,
		OccurredAt: time.Now(),
	}
	return existing, &event, nil
}
