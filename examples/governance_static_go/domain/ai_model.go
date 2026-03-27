package domain

import (
	"time"
	"github.com/google/uuid"
)

type AiModel struct {
	ID        string    `json:"id"`
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
	CreatedAt time.Time `json:"created_at"`
	UpdatedAt time.Time `json:"updated_at"`
}

func NewAiModel(name string, version string, providerId string, description string, riskLevel string, registeredAt time.Time, parentModelId string, derivationType string, capabilities []Capability, intendedUses []IntendedUse, status string) *AiModel {
	a := &AiModel{
		ID:        uuid.New().String(),
		Name: name,
		Version: version,
		ProviderId: providerId,
		Description: description,
		RiskLevel: riskLevel,
		RegisteredAt: registeredAt,
		ParentModelId: parentModelId,
		DerivationType: derivationType,
		Capabilities: capabilities,
		IntendedUses: intendedUses,
		Status: status,
		CreatedAt: time.Now(),
		UpdatedAt: time.Now(),
	}
	return a
}

func (a *AiModel) Validate() error {
	return nil
}
