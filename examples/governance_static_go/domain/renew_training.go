package domain

import (
	"time"
	"fmt"
)

type RenewTraining struct {
	TrainingRecordId string `json:"training_record_id"`
	Certification string `json:"certification"`
	ExpiresAt time.Time `json:"expires_at"`
}

func (c RenewTraining) CommandName() string { return "RenewTraining" }

func (c RenewTraining) Execute(repo TrainingRecordRepository) (*TrainingRecord, *RenewedTraining, error) {
	existing, err := repo.Find(c.TrainingRecordId)
	if err != nil {
		return nil, nil, err
	}
	if existing == nil {
		return nil, nil, fmt.Errorf("TrainingRecord not found: %s", c.TrainingRecordId)
	}
	existing.Certification = c.Certification
	existing.ExpiresAt = c.ExpiresAt
	if existing.Status != "completed" {
		return nil, nil, fmt.Errorf("cannot RenewTraining: TrainingRecord is in %s state", existing.Status)
	}
	existing.Status = "completed"
	existing.UpdatedAt = time.Now()
	if err := existing.Validate(); err != nil {
		return nil, nil, err
	}
	if err := repo.Save(existing); err != nil {
		return nil, nil, err
	}
	event := RenewedTraining{
		AggregateID: existing.ID,
		TrainingRecordId: c.TrainingRecordId,
		Certification: c.Certification,
		ExpiresAt: c.ExpiresAt,
		OccurredAt: time.Now(),
	}
	return existing, &event, nil
}
