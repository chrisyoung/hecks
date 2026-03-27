package domain

import "time"

type CreatedPizza struct {
	AggregateID string    `json:"aggregate_id"`
	AggregateId string `json:"aggregate_id"`
	Name string `json:"name"`
	Description string `json:"description"`
	Toppings []Topping `json:"toppings"`
	OccurredAt time.Time `json:"occurred_at"`
}

func (e CreatedPizza) EventName() string { return "CreatedPizza" }

func (e CreatedPizza) GetOccurredAt() time.Time { return e.OccurredAt }
