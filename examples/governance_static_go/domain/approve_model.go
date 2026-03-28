package domain

import (
	"time"
	"fmt"
)

type ApproveModel struct {
	ModelId string `json:"model_id"`
}

func (c ApproveModel) CommandName() string { return "ApproveModel" }

func (c ApproveModel) Execute(repo AiModelRepository) (*AiModel, *ApprovedModel, error) {
	existing, err := repo.Find(c.ModelId)
	if err != nil {
		return nil, nil, err
	}
	if existing == nil {
		return nil, nil, fmt.Errorf("AiModel not found: %s", c.ModelId)
	}
	if existing.Status != "classified" {
		return nil, nil, fmt.Errorf("cannot ApproveModel: AiModel is in %s state", existing.Status)
	}
	existing.Status = "approved"
	existing.UpdatedAt = time.Now()
	if err := existing.Validate(); err != nil {
		return nil, nil, err
	}
	if err := repo.Save(existing); err != nil {
		return nil, nil, err
	}
	event := ApprovedModel{
		AggregateID: existing.ID,
		ModelId: c.ModelId,
		OccurredAt: time.Now(),
	}
	return existing, &event, nil
}
