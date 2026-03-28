package domain

import (
	"time"
	"github.com/google/uuid"
	"fmt"
)

type DataUsageAgreement struct {
	ID string `json:"id"`
	CreatedAt time.Time `json:"created_at"`
	UpdatedAt time.Time `json:"updated_at"`
	ModelId string `json:"model_id"`
	DataSource string `json:"data_source"`
	Purpose string `json:"purpose"`
	ConsentType string `json:"consent_type"`
	EffectiveDate time.Time `json:"effective_date"`
	ExpirationDate time.Time `json:"expiration_date"`
	Restrictions []Restriction `json:"restrictions"`
	Status string `json:"status"`
}

func NewDataUsageAgreement(modelId string, dataSource string, purpose string, consentType string, effectiveDate time.Time, expirationDate time.Time, restrictions []Restriction, status string) *DataUsageAgreement {
	a := &DataUsageAgreement{
		ID:        uuid.New().String(),
		ModelId: modelId,
		DataSource: dataSource,
		Purpose: purpose,
		ConsentType: consentType,
		EffectiveDate: effectiveDate,
		ExpirationDate: expirationDate,
		Restrictions: restrictions,
		Status: status,
		CreatedAt: time.Now(),
		UpdatedAt: time.Now(),
	}
	return a
}

func (a *DataUsageAgreement) Validate() error {
	if a.DataSource == "" {
		return &ValidationError{Field: "data_source", Message: "data_source can't be blank"}
	}
	if a.Purpose == "" {
		return &ValidationError{Field: "purpose", Message: "purpose can't be blank"}
	}
	if a.ConsentType != "" {
		validConsentType := map[string]bool{"public_domain": true, "CC-BY-SA": true, "licensed": true, "consent": true, "opt-out": true}
		if !validConsentType[a.ConsentType] {
			return &ValidationError{Field: "consent_type", Message: fmt.Sprintf("consent_type must be one of: public_domain, CC-BY-SA, licensed, consent, opt-out, got: %s", a.ConsentType)}
		}
	}
	// invariant: expiration must be after effective date
	return nil
}
