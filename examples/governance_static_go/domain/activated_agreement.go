package domain

import "time"

type ActivatedAgreement struct {
	AggregateID string    `json:"aggregate_id"`
	AggregateId string `json:"aggregate_id"`
	AgreementId string `json:"agreement_id"`
	EffectiveDate time.Time `json:"effective_date"`
	ExpirationDate time.Time `json:"expiration_date"`
	ModelId string `json:"model_id"`
	DataSource string `json:"data_source"`
	Purpose string `json:"purpose"`
	ConsentType string `json:"consent_type"`
	Restrictions []Restriction `json:"restrictions"`
	Status string `json:"status"`
	OccurredAt time.Time `json:"occurred_at"`
}

func (e ActivatedAgreement) EventName() string { return "ActivatedAgreement" }

func (e ActivatedAgreement) GetOccurredAt() time.Time { return e.OccurredAt }
