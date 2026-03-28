package domain

import (
	"time"
	"fmt"
)

type ClassifyRisk struct {
	ModelId string `json:"model_id"`
	RiskLevel string `json:"risk_level"`
}

func (c ClassifyRisk) CommandName() string { return "ClassifyRisk" }

func (c ClassifyRisk) Execute(repo AiModelRepository) (*AiModel, *ClassifiedRisk, error) {
	existing, err := repo.Find(c.ModelId)
	if err != nil {
		return nil, nil, err
	}
	if existing == nil {
		return nil, nil, fmt.Errorf("AiModel not found: %s", c.ModelId)
	}
	existing.RiskLevel = c.RiskLevel
	if existing.Status != "draft" {
		return nil, nil, fmt.Errorf("cannot ClassifyRisk: AiModel is in %s state", existing.Status)
	}
	existing.Status = "classified"
	existing.UpdatedAt = time.Now()
	if err := existing.Validate(); err != nil {
		return nil, nil, err
	}
	if err := repo.Save(existing); err != nil {
		return nil, nil, err
	}
	event := ClassifiedRisk{
		AggregateID: existing.ID,
		ModelId: c.ModelId,
		RiskLevel: c.RiskLevel,
		OccurredAt: time.Now(),
	}
	return existing, &event, nil
}
