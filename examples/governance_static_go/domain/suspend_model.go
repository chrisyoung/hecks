package domain

import (
	"time"
)

type SuspendModel struct {
	ModelId string `json:"model_id"`
}

func (c SuspendModel) CommandName() string { return "SuspendModel" }

func (c SuspendModel) Execute(repo AiModelRepository) (*AiModel, *SuspendedModel, error) {
	agg := NewAiModel("", "", "", "", "", time.Time{}, "", "", nil, nil, "")
	if err := agg.Validate(); err != nil {
		return nil, nil, err
	}
	if err := repo.Save(agg); err != nil {
		return nil, nil, err
	}
	event := SuspendedModel{
		AggregateID: agg.ID,
		ModelId: c.ModelId,
		OccurredAt: time.Now(),
	}
	return agg, &event, nil
}
