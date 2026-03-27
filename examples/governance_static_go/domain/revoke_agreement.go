package domain

import (
	"time"
)

type RevokeAgreement struct {
	AgreementId string `json:"agreement_id"`
}

func (c RevokeAgreement) CommandName() string { return "RevokeAgreement" }

func (c RevokeAgreement) Execute(repo DataUsageAgreementRepository) (*DataUsageAgreement, *RevokedAgreement, error) {
	agg := NewDataUsageAgreement("", "", "", "", time.Time{}, time.Time{}, nil, "")
	if err := agg.Validate(); err != nil {
		return nil, nil, err
	}
	if err := repo.Save(agg); err != nil {
		return nil, nil, err
	}
	event := RevokedAgreement{
		AggregateID: agg.ID,
		AgreementId: c.AgreementId,
		OccurredAt: time.Now(),
	}
	return agg, &event, nil
}
