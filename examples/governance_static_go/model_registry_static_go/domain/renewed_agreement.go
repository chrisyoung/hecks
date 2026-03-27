package domain

import "time"

type RenewedAgreement struct {
	AggregateID string    `json:"aggregate_id"`
	AggregateId string `json:"aggregate_id"`
	AgreementId string `json:"agreement_id"`
	ExpirationDate time.Time `json:"expiration_date"`
	ModelId string `json:"model_id"`
	DataSource string `json:"data_source"`
	Purpose string `json:"purpose"`
	ConsentType string `json:"consent_type"`
	EffectiveDate time.Time `json:"effective_date"`
	Restrictions []Restriction `json:"restrictions"`
	Status string `json:"status"`
	OccurredAt time.Time `json:"occurred_at"`
}

func (e RenewedAgreement) EventName() string { return "RenewedAgreement" }

func (e RenewedAgreement) GetOccurredAt() time.Time { return e.OccurredAt }
