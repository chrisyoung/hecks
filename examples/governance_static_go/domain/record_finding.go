package domain

import (
	"time"
	"fmt"
)

type RecordFinding struct {
	AssessmentId string `json:"assessment_id"`
	Category string `json:"category"`
	Severity string `json:"severity"`
	Description string `json:"description"`
}

func (c RecordFinding) CommandName() string { return "RecordFinding" }

func (c RecordFinding) Execute(repo AssessmentRepository) (*Assessment, *RecordedFinding, error) {
	existing, err := repo.Find(c.AssessmentId)
	if err != nil {
		return nil, nil, err
	}
	if existing == nil {
		return nil, nil, fmt.Errorf("Assessment not found: %s", c.AssessmentId)
	}
	existing.UpdatedAt = time.Now()
	if err := existing.Validate(); err != nil {
		return nil, nil, err
	}
	if err := repo.Save(existing); err != nil {
		return nil, nil, err
	}
	event := RecordedFinding{
		AggregateID: existing.ID,
		AssessmentId: c.AssessmentId,
		Category: c.Category,
		Severity: c.Severity,
		Description: c.Description,
		OccurredAt: time.Now(),
	}
	return existing, &event, nil
}
