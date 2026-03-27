package domain

import "time"

type CanceledOrder struct {
	AggregateID string    `json:"aggregate_id"`
	AggregateId string `json:"aggregate_id"`
	OrderId string `json:"order_id"`
	CustomerName string `json:"customer_name"`
	Items []Orderitem `json:"items"`
	Status string `json:"status"`
	OccurredAt time.Time `json:"occurred_at"`
}

func (e CanceledOrder) EventName() string { return "CanceledOrder" }

func (e CanceledOrder) GetOccurredAt() time.Time { return e.OccurredAt }
