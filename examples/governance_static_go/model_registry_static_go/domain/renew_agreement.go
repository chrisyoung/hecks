package domain

import (
	"time"
)

type RenewAgreement struct {
	AgreementId string `json:"agreement_id"`
	ExpirationDate time.Time `json:"expiration_date"`
}

func (c RenewAgreement) CommandName() string { return "RenewAgreement" }

func (c RenewAgreement) Execute(repo DataUsageAgreementRepository) (*DataUsageAgreement, *RenewedAgreement, error) {
	agg := NewDataUsageAgreement("", "", "", "", time.Time{}, c.ExpirationDate, nil, "")
	if err := agg.Validate(); err != nil {
		return nil, nil, err
	}
	if err := repo.Save(agg); err != nil {
		return nil, nil, err
	}
	event := RenewedAgreement{
		AggregateID: agg.ID,
		AgreementId: c.AgreementId,
		ExpirationDate: c.ExpirationDate,
		OccurredAt: time.Now(),
	}
	return agg, &event, nil
}
