package domain

import (
	"time"
)

type InitiateAssessment struct {
	ModelId string `json:"model_id"`
	AssessorId string `json:"assessor_id"`
}

func (c InitiateAssessment) CommandName() string { return "InitiateAssessment" }

func (c InitiateAssessment) Execute(repo AssessmentRepository) (*Assessment, *InitiatedAssessment, error) {
	agg := NewAssessment(c.ModelId, c.AssessorId, "", 0.0, 0.0, 0.0, 0.0, time.Time{}, nil, nil, "")
	if err := agg.Validate(); err != nil {
		return nil, nil, err
	}
	if err := repo.Save(agg); err != nil {
		return nil, nil, err
	}
	event := InitiatedAssessment{
		AggregateID: agg.ID,
		ModelId: c.ModelId,
		AssessorId: c.AssessorId,
		OccurredAt: time.Now(),
	}
	return agg, &event, nil
}
