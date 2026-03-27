package domain

import (
	"time"
)

type ActivateAgreement struct {
	AgreementId string `json:"agreement_id"`
	EffectiveDate time.Time `json:"effective_date"`
	ExpirationDate time.Time `json:"expiration_date"`
}

func (c ActivateAgreement) CommandName() string { return "ActivateAgreement" }

func (c ActivateAgreement) Execute(repo DataUsageAgreementRepository) (*DataUsageAgreement, *ActivatedAgreement, error) {
	agg := NewDataUsageAgreement("", "", "", "", c.EffectiveDate, c.ExpirationDate, nil, "")
	if err := agg.Validate(); err != nil {
		return nil, nil, err
	}
	if err := repo.Save(agg); err != nil {
		return nil, nil, err
	}
	event := ActivatedAgreement{
		AggregateID: agg.ID,
		AgreementId: c.AgreementId,
		EffectiveDate: c.EffectiveDate,
		ExpirationDate: c.ExpirationDate,
		OccurredAt: time.Now(),
	}
	return agg, &event, nil
}
