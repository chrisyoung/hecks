package domain

import (
	"time"
	"fmt"
)

type CompleteTraining struct {
	TrainingRecordId string `json:"training_record_id"`
	Certification string `json:"certification"`
	ExpiresAt time.Time `json:"expires_at"`
}

func (c CompleteTraining) CommandName() string { return "CompleteTraining" }

func (c CompleteTraining) Execute(repo TrainingRecordRepository) (*TrainingRecord, *CompletedTraining, error) {
	existing, err := repo.Find(c.TrainingRecordId)
	if err != nil {
		return nil, nil, err
	}
	if existing == nil {
		return nil, nil, fmt.Errorf("TrainingRecord not found: %s", c.TrainingRecordId)
	}
	existing.Certification = c.Certification
	existing.ExpiresAt = c.ExpiresAt
	if existing.Status != "assigned" {
		return nil, nil, fmt.Errorf("cannot CompleteTraining: TrainingRecord is in %s state", existing.Status)
	}
	existing.Status = "completed"
	existing.UpdatedAt = time.Now()
	if err := existing.Validate(); err != nil {
		return nil, nil, err
	}
	if err := repo.Save(existing); err != nil {
		return nil, nil, err
	}
	event := CompletedTraining{
		AggregateID: existing.ID,
		TrainingRecordId: c.TrainingRecordId,
		Certification: c.Certification,
		ExpiresAt: c.ExpiresAt,
		OccurredAt: time.Now(),
	}
	return existing, &event, nil
}
