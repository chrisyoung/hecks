package domain

import (
	"time"
)

type PlaceOrder struct {
	CustomerName string `json:"customer_name"`
	PizzaId string `json:"pizza_id"`
	Quantity int64 `json:"quantity"`
}

func (c PlaceOrder) CommandName() string { return "PlaceOrder" }

func (c PlaceOrder) Execute(repo OrderRepository) (*Order, *PlacedOrder, error) {
	agg := NewOrder(c.CustomerName, nil, "")
	if err := agg.Validate(); err != nil {
		return nil, nil, err
	}
	if err := repo.Save(agg); err != nil {
		return nil, nil, err
	}
	event := PlacedOrder{
		AggregateID: agg.ID,
		CustomerName: c.CustomerName,
		PizzaId: c.PizzaId,
		Quantity: c.Quantity,
		OccurredAt: time.Now(),
	}
	return agg, &event, nil
}
