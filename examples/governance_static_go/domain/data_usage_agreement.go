package domain

import (
	"time"
	"github.com/google/uuid"
)

type DataUsageAgreement struct {
	ID        string    `json:"id"`
	ModelId string `json:"model_id"`
	DataSource string `json:"data_source"`
	Purpose string `json:"purpose"`
	ConsentType string `json:"consent_type"`
	EffectiveDate time.Time `json:"effective_date"`
	ExpirationDate time.Time `json:"expiration_date"`
	Restrictions []Restriction `json:"restrictions"`
	Status string `json:"status"`
	CreatedAt time.Time `json:"created_at"`
	UpdatedAt time.Time `json:"updated_at"`
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
	return nil
}
