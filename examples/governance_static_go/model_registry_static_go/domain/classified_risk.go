package domain

import "time"

type ClassifiedRisk struct {
	AggregateID string    `json:"aggregate_id"`
	AggregateId string `json:"aggregate_id"`
	ModelId string `json:"model_id"`
	RiskLevel string `json:"risk_level"`
	Name string `json:"name"`
	Version string `json:"version"`
	ProviderId string `json:"provider_id"`
	Description string `json:"description"`
	RegisteredAt time.Time `json:"registered_at"`
	ParentModelId string `json:"parent_model_id"`
	DerivationType string `json:"derivation_type"`
	Capabilities []Capability `json:"capabilities"`
	IntendedUses []IntendedUse `json:"intended_uses"`
	Status string `json:"status"`
	OccurredAt time.Time `json:"occurred_at"`
}

func (e ClassifiedRisk) EventName() string { return "ClassifiedRisk" }

func (e ClassifiedRisk) GetOccurredAt() time.Time { return e.OccurredAt }
