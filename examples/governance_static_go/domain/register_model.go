package domain

import (
	"time"
)

type RegisterModel struct {
	Name string `json:"name"`
	Version string `json:"version"`
	ProviderId string `json:"provider_id"`
	Description string `json:"description"`
}

func (c RegisterModel) CommandName() string { return "RegisterModel" }

func (c RegisterModel) Execute(repo AiModelRepository) (*AiModel, *RegisteredModel, error) {
	agg := NewAiModel(c.Name, c.Version, c.ProviderId, c.Description, "", time.Time{}, "", "", nil, nil, "")
	agg.Status = "draft"
	if err := agg.Validate(); err != nil {
		return nil, nil, err
	}
	if err := repo.Save(agg); err != nil {
		return nil, nil, err
	}
	event := RegisteredModel{
		AggregateID: agg.ID,
		Name: c.Name,
		Version: c.Version,
		ProviderId: c.ProviderId,
		Description: c.Description,
		OccurredAt: time.Now(),
	}
	return agg, &event, nil
}
