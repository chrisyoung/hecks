package domain

import (
	"time"
	"fmt"
)

type RenewAgreement struct {
	AgreementId string `json:"agreement_id"`
	ExpirationDate time.Time `json:"expiration_date"`
}

func (c RenewAgreement) CommandName() string { return "RenewAgreement" }

func (c RenewAgreement) Execute(repo DataUsageAgreementRepository) (*DataUsageAgreement, *RenewedAgreement, error) {
	existing, err := repo.Find(c.AgreementId)
	if err != nil {
		return nil, nil, err
	}
	if existing == nil {
		return nil, nil, fmt.Errorf("DataUsageAgreement not found: %s", c.AgreementId)
	}
	existing.ExpirationDate = c.ExpirationDate
	if existing.Status != "active" && existing.Status != "revoked" {
		return nil, nil, fmt.Errorf("cannot RenewAgreement: DataUsageAgreement is in %s state", existing.Status)
	}
	existing.Status = "active"
	existing.UpdatedAt = time.Now()
	if err := existing.Validate(); err != nil {
		return nil, nil, err
	}
	if err := repo.Save(existing); err != nil {
		return nil, nil, err
	}
	event := RenewedAgreement{
		AggregateID: existing.ID,
		AgreementId: c.AgreementId,
		ExpirationDate: c.ExpirationDate,
		OccurredAt: time.Now(),
	}
	return existing, &event, nil
}
