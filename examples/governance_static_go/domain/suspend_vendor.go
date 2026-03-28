package domain

import (
	"time"
	"fmt"
)

type SuspendVendor struct {
	VendorId string `json:"vendor_id"`
}

func (c SuspendVendor) CommandName() string { return "SuspendVendor" }

func (c SuspendVendor) Execute(repo VendorRepository) (*Vendor, *SuspendedVendor, error) {
	existing, err := repo.Find(c.VendorId)
	if err != nil {
		return nil, nil, err
	}
	if existing == nil {
		return nil, nil, fmt.Errorf("Vendor not found: %s", c.VendorId)
	}
	if existing.Status != "approved" {
		return nil, nil, fmt.Errorf("cannot SuspendVendor: Vendor is in %s state", existing.Status)
	}
	existing.Status = "suspended"
	existing.UpdatedAt = time.Now()
	if err := existing.Validate(); err != nil {
		return nil, nil, err
	}
	if err := repo.Save(existing); err != nil {
		return nil, nil, err
	}
	event := SuspendedVendor{
		AggregateID: existing.ID,
		VendorId: c.VendorId,
		OccurredAt: time.Now(),
	}
	return existing, &event, nil
}
