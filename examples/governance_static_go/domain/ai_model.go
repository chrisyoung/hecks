package domain

import (
	"time"
	"github.com/google/uuid"
	"fmt"
)

type AiModel struct {
	ID string `json:"id"`
	CreatedAt time.Time `json:"created_at"`
	UpdatedAt time.Time `json:"updated_at"`
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
	if a.Name == "" {
		return &ValidationError{Field: "name", Message: "name can't be blank"}
	}
	if a.Version == "" {
		return &ValidationError{Field: "version", Message: "version can't be blank"}
	}
	if a.RiskLevel != "" {
		validRiskLevel := map[string]bool{"low": true, "medium": true, "high": true, "critical": true}
		if !validRiskLevel[a.RiskLevel] {
			return &ValidationError{Field: "risk_level", Message: fmt.Sprintf("risk_level must be one of: low, medium, high, critical, got: %s", a.RiskLevel)}
		}
	}
	if a.DerivationType != "" {
		validDerivationType := map[string]bool{"fine-tuned": true, "distilled": true, "retrained": true, "quantized": true}
		if !validDerivationType[a.DerivationType] {
			return &ValidationError{Field: "derivation_type", Message: fmt.Sprintf("derivation_type must be one of: fine-tuned, distilled, retrained, quantized, got: %s", a.DerivationType)}
		}
	}
	return nil
}
