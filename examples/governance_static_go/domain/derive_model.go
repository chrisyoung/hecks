package domain

import (
	"time"
)

type DeriveModel struct {
	Name string `json:"name"`
	Version string `json:"version"`
	ParentModelId string `json:"parent_model_id"`
	DerivationType string `json:"derivation_type"`
	Description string `json:"description"`
}

func (c DeriveModel) CommandName() string { return "DeriveModel" }

func (c DeriveModel) Execute(repo AiModelRepository) (*AiModel, *DerivedModel, error) {
	agg := NewAiModel(c.Name, c.Version, "", c.Description, "", time.Time{}, c.ParentModelId, c.DerivationType, nil, nil, "")
	if err := agg.Validate(); err != nil {
		return nil, nil, err
	}
	if err := repo.Save(agg); err != nil {
		return nil, nil, err
	}
	event := DerivedModel{
		AggregateID: agg.ID,
		Name: c.Name,
		Version: c.Version,
		ParentModelId: c.ParentModelId,
		DerivationType: c.DerivationType,
		Description: c.Description,
		OccurredAt: time.Now(),
	}
	return agg, &event, nil
}
