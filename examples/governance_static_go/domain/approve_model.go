package domain

import (
	"time"
)

type ApproveModel struct {
	ModelId string `json:"model_id"`
}

func (c ApproveModel) CommandName() string { return "ApproveModel" }

func (c ApproveModel) Execute(repo AiModelRepository) (*AiModel, *ApprovedModel, error) {
	agg := NewAiModel("", "", "", "", "", time.Time{}, "", "", nil, nil, "")
	if err := agg.Validate(); err != nil {
		return nil, nil, err
	}
	if err := repo.Save(agg); err != nil {
		return nil, nil, err
	}
	event := ApprovedModel{
		AggregateID: agg.ID,
		ModelId: c.ModelId,
		OccurredAt: time.Now(),
	}
	return agg, &event, nil
}
