package domain

import "time"

type CreatedAgreement struct {
	AggregateID string    `json:"aggregate_id"`
	AggregateId string `json:"aggregate_id"`
	ModelId string `json:"model_id"`
	DataSource string `json:"data_source"`
	Purpose string `json:"purpose"`
	ConsentType string `json:"consent_type"`
	EffectiveDate time.Time `json:"effective_date"`
	ExpirationDate time.Time `json:"expiration_date"`
	Restrictions []Restriction `json:"restrictions"`
	Status string `json:"status"`
	OccurredAt time.Time `json:"occurred_at"`
}

func (e CreatedAgreement) EventName() string { return "CreatedAgreement" }

func (e CreatedAgreement) GetOccurredAt() time.Time { return e.OccurredAt }
