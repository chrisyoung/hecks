package domain

import (
	"time"
)

type RetireModel struct {
	ModelId string `json:"model_id"`
}

func (c RetireModel) CommandName() string { return "RetireModel" }

func (c RetireModel) Execute(repo AiModelRepository) (*AiModel, *RetiredModel, error) {
	agg := NewAiModel("", "", "", "", "", time.Time{}, "", "", nil, nil, "")
	if err := agg.Validate(); err != nil {
		return nil, nil, err
	}
	if err := repo.Save(agg); err != nil {
		return nil, nil, err
	}
	event := RetiredModel{
		AggregateID: agg.ID,
		ModelId: c.ModelId,
		OccurredAt: time.Now(),
	}
	return agg, &event, nil
}
