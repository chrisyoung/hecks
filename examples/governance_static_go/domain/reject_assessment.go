package domain

import (
	"time"
	"fmt"
)

type RejectAssessment struct {
	AssessmentId string `json:"assessment_id"`
}

func (c RejectAssessment) CommandName() string { return "RejectAssessment" }

func (c RejectAssessment) Execute(repo AssessmentRepository) (*Assessment, *RejectedAssessment, error) {
	existing, err := repo.Find(c.AssessmentId)
	if err != nil {
		return nil, nil, err
	}
	if existing == nil {
		return nil, nil, fmt.Errorf("Assessment not found: %s", c.AssessmentId)
	}
	if existing.Status != "pending" && existing.Status != "submitted" {
		return nil, nil, fmt.Errorf("cannot RejectAssessment: Assessment is in %s state", existing.Status)
	}
	existing.Status = "rejected"
	existing.UpdatedAt = time.Now()
	if err := existing.Validate(); err != nil {
		return nil, nil, err
	}
	if err := repo.Save(existing); err != nil {
		return nil, nil, err
	}
	event := RejectedAssessment{
		AggregateID: existing.ID,
		AssessmentId: c.AssessmentId,
		OccurredAt: time.Now(),
	}
	return existing, &event, nil
}
