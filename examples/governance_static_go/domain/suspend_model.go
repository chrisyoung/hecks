package domain

import (
	"time"
	"fmt"
)

type SuspendModel struct {
	ModelId string `json:"model_id"`
}

func (c SuspendModel) CommandName() string { return "SuspendModel" }

func (c SuspendModel) Execute(repo AiModelRepository) (*AiModel, *SuspendedModel, error) {
	existing, err := repo.Find(c.ModelId)
	if err != nil {
		return nil, nil, err
	}
	if existing == nil {
		return nil, nil, fmt.Errorf("AiModel not found: %s", c.ModelId)
	}
	if existing.Status != "approved" && existing.Status != "classified" && existing.Status != "draft" {
		return nil, nil, fmt.Errorf("cannot SuspendModel: AiModel is in %s state", existing.Status)
	}
	existing.Status = "suspended"
	existing.UpdatedAt = time.Now()
	if err := existing.Validate(); err != nil {
		return nil, nil, err
	}
	if err := repo.Save(existing); err != nil {
		return nil, nil, err
	}
	event := SuspendedModel{
		AggregateID: existing.ID,
		ModelId: c.ModelId,
		OccurredAt: time.Now(),
	}
	return existing, &event, nil
}
