package domain

import "time"

type DerivedModel struct {
	AggregateID string    `json:"aggregate_id"`
	AggregateId string `json:"aggregate_id"`
	Name string `json:"name"`
	Version string `json:"version"`
	ParentModelId string `json:"parent_model_id"`
	DerivationType string `json:"derivation_type"`
	Description string `json:"description"`
	ProviderId string `json:"provider_id"`
	RiskLevel string `json:"risk_level"`
	RegisteredAt time.Time `json:"registered_at"`
	Capabilities []Capability `json:"capabilities"`
	IntendedUses []IntendedUse `json:"intended_uses"`
	Status string `json:"status"`
	OccurredAt time.Time `json:"occurred_at"`
}

func (e DerivedModel) EventName() string { return "DerivedModel" }

func (e DerivedModel) GetOccurredAt() time.Time { return e.OccurredAt }
