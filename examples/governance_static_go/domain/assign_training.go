package domain

import (
	"time"
)

type AssignTraining struct {
	StakeholderId string `json:"stakeholder_id"`
	PolicyId string `json:"policy_id"`
}

func (c AssignTraining) CommandName() string { return "AssignTraining" }

func (c AssignTraining) Execute(repo TrainingRecordRepository) (*TrainingRecord, *AssignedTraining, error) {
	agg := NewTrainingRecord(c.StakeholderId, c.PolicyId, time.Time{}, time.Time{}, "", "")
	agg.Status = "assigned"
	if err := agg.Validate(); err != nil {
		return nil, nil, err
	}
	if err := repo.Save(agg); err != nil {
		return nil, nil, err
	}
	event := AssignedTraining{
		AggregateID: agg.ID,
		StakeholderId: c.StakeholderId,
		PolicyId: c.PolicyId,
		OccurredAt: time.Now(),
	}
	return agg, &event, nil
}
