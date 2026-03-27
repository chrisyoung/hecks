package domain

import "time"

type ApprovedModel struct {
	AggregateID string    `json:"aggregate_id"`
	AggregateId string `json:"aggregate_id"`
	ModelId string `json:"model_id"`
	Name string `json:"name"`
	Version string `json:"version"`
	ProviderId string `json:"provider_id"`
	Description string `json:"description"`
	RiskLevel string `json:"risk_level"`
	RegisteredAt time.Time `json:"registered_at"`
	ParentModelId string `json:"parent_model_id"`
	DerivationType string `json:"derivation_type"`
	Capabilities []Capability `json:"capabilities"`
	IntendedUses []IntendedUse `json:"intended_uses"`
	Status string `json:"status"`
	OccurredAt time.Time `json:"occurred_at"`
}

func (e ApprovedModel) EventName() string { return "ApprovedModel" }

func (e ApprovedModel) GetOccurredAt() time.Time { return e.OccurredAt }
