package domain

import (
	"time"
)

type RegisterVendor struct {
	Name string `json:"name"`
	ContactEmail string `json:"contact_email"`
	RiskTier string `json:"risk_tier"`
}

func (c RegisterVendor) CommandName() string { return "RegisterVendor" }

func (c RegisterVendor) Execute(repo VendorRepository) (*Vendor, *RegisteredVendor, error) {
	agg := NewVendor(c.Name, c.ContactEmail, c.RiskTier, time.Time{}, time.Time{}, "", "")
	if err := agg.Validate(); err != nil {
		return nil, nil, err
	}
	if err := repo.Save(agg); err != nil {
		return nil, nil, err
	}
	event := RegisteredVendor{
		AggregateID: agg.ID,
		Name: c.Name,
		ContactEmail: c.ContactEmail,
		RiskTier: c.RiskTier,
		OccurredAt: time.Now(),
	}
	return agg, &event, nil
}
