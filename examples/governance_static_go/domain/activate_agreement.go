package domain

import (
	"time"
	"fmt"
)

type ActivateAgreement struct {
	AgreementId string `json:"agreement_id"`
	EffectiveDate time.Time `json:"effective_date"`
	ExpirationDate time.Time `json:"expiration_date"`
}

func (c ActivateAgreement) CommandName() string { return "ActivateAgreement" }

func (c ActivateAgreement) Execute(repo DataUsageAgreementRepository) (*DataUsageAgreement, *ActivatedAgreement, error) {
	existing, err := repo.Find(c.AgreementId)
	if err != nil {
		return nil, nil, err
	}
	if existing == nil {
		return nil, nil, fmt.Errorf("DataUsageAgreement not found: %s", c.AgreementId)
	}
	existing.EffectiveDate = c.EffectiveDate
	existing.ExpirationDate = c.ExpirationDate
	if existing.Status != "draft" {
		return nil, nil, fmt.Errorf("cannot ActivateAgreement: DataUsageAgreement is in %s state", existing.Status)
	}
	existing.Status = "active"
	existing.UpdatedAt = time.Now()
	if err := existing.Validate(); err != nil {
		return nil, nil, err
	}
	if err := repo.Save(existing); err != nil {
		return nil, nil, err
	}
	event := ActivatedAgreement{
		AggregateID: existing.ID,
		AgreementId: c.AgreementId,
		EffectiveDate: c.EffectiveDate,
		ExpirationDate: c.ExpirationDate,
		OccurredAt: time.Now(),
	}
	return existing, &event, nil
}
