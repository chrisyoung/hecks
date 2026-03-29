package domain

import (
	"time"
	"fmt"
)

type CancelOrder struct {
	OrderId string `json:"order_id"`
}

func (c CancelOrder) CommandName() string { return "CancelOrder" }

func (c CancelOrder) Execute(repo OrderRepository) (*Order, *CanceledOrder, error) {
	existing, err := repo.Find(c.OrderId)
	if err != nil {
		return nil, nil, err
	}
	if existing == nil {
		return nil, nil, fmt.Errorf("Order not found: %s", c.OrderId)
	}
	existing.Status = "cancelled"
	existing.UpdatedAt = time.Now()
	if err := existing.Validate(); err != nil {
		return nil, nil, err
	}
	if err := repo.Save(existing); err != nil {
		return nil, nil, err
	}
	event := CanceledOrder{
		AggregateID: existing.ID,
		OrderId: c.OrderId,
		OccurredAt: time.Now(),
	}
	return existing, &event, nil
}
