package domain

import (
	"time"
)

type CreateAgreement struct {
	ModelId string `json:"model_id"`
	DataSource string `json:"data_source"`
	Purpose string `json:"purpose"`
	ConsentType string `json:"consent_type"`
}

func (c CreateAgreement) CommandName() string { return "CreateAgreement" }

func (c CreateAgreement) Execute(repo DataUsageAgreementRepository) (*DataUsageAgreement, *CreatedAgreement, error) {
	agg := NewDataUsageAgreement(c.ModelId, c.DataSource, c.Purpose, c.ConsentType, time.Time{}, time.Time{}, nil, "")
	agg.Status = "draft"
	if err := agg.Validate(); err != nil {
		return nil, nil, err
	}
	if err := repo.Save(agg); err != nil {
		return nil, nil, err
	}
	event := CreatedAgreement{
		AggregateID: agg.ID,
		ModelId: c.ModelId,
		DataSource: c.DataSource,
		Purpose: c.Purpose,
		ConsentType: c.ConsentType,
		OccurredAt: time.Now(),
	}
	return agg, &event, nil
}
