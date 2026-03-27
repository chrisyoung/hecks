package domain

import (
	"time"
)

type ClassifyRisk struct {
	ModelId string `json:"model_id"`
	RiskLevel string `json:"risk_level"`
}

func (c ClassifyRisk) CommandName() string { return "ClassifyRisk" }

func (c ClassifyRisk) Execute(repo AiModelRepository) (*AiModel, *ClassifiedRisk, error) {
	agg := NewAiModel("", "", "", "", c.RiskLevel, time.Time{}, "", "", nil, nil, "")
	if err := agg.Validate(); err != nil {
		return nil, nil, err
	}
	if err := repo.Save(agg); err != nil {
		return nil, nil, err
	}
	event := ClassifiedRisk{
		AggregateID: agg.ID,
		ModelId: c.ModelId,
		RiskLevel: c.RiskLevel,
		OccurredAt: time.Now(),
	}
	return agg, &event, nil
}
