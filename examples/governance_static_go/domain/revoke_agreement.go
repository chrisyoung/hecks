package domain

import (
	"time"
	"fmt"
)

type RevokeAgreement struct {
	AgreementId string `json:"agreement_id"`
}

func (c RevokeAgreement) CommandName() string { return "RevokeAgreement" }

func (c RevokeAgreement) Execute(repo DataUsageAgreementRepository) (*DataUsageAgreement, *RevokedAgreement, error) {
	existing, err := repo.Find(c.AgreementId)
	if err != nil {
		return nil, nil, err
	}
	if existing == nil {
		return nil, nil, fmt.Errorf("DataUsageAgreement not found: %s", c.AgreementId)
	}
	if existing.Status != "active" {
		return nil, nil, fmt.Errorf("cannot RevokeAgreement: DataUsageAgreement is in %s state", existing.Status)
	}
	existing.Status = "revoked"
	existing.UpdatedAt = time.Now()
	if err := existing.Validate(); err != nil {
		return nil, nil, err
	}
	if err := repo.Save(existing); err != nil {
		return nil, nil, err
	}
	event := RevokedAgreement{
		AggregateID: existing.ID,
		AgreementId: c.AgreementId,
		OccurredAt: time.Now(),
	}
	return existing, &event, nil
}
