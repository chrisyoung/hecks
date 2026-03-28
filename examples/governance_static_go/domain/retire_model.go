package domain

import (
	"time"
	"fmt"
)

type RetireModel struct {
	ModelId string `json:"model_id"`
}

func (c RetireModel) CommandName() string { return "RetireModel" }

func (c RetireModel) Execute(repo AiModelRepository) (*AiModel, *RetiredModel, error) {
	existing, err := repo.Find(c.ModelId)
	if err != nil {
		return nil, nil, err
	}
	if existing == nil {
		return nil, nil, fmt.Errorf("AiModel not found: %s", c.ModelId)
	}
	if existing.Status != "approved" && existing.Status != "suspended" {
		return nil, nil, fmt.Errorf("cannot RetireModel: AiModel is in %s state", existing.Status)
	}
	existing.Status = "retired"
	existing.UpdatedAt = time.Now()
	if err := existing.Validate(); err != nil {
		return nil, nil, err
	}
	if err := repo.Save(existing); err != nil {
		return nil, nil, err
	}
	event := RetiredModel{
		AggregateID: existing.ID,
		ModelId: c.ModelId,
		OccurredAt: time.Now(),
	}
	return existing, &event, nil
}
