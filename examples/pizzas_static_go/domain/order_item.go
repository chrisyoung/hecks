package domain

import "fmt"

type OrderItem struct {
	PizzaId string `json:"pizza_id"`
	Quantity int64 `json:"quantity"`
}

func NewOrderItem(pizzaId string, quantity int64) (OrderItem, error) {
	v := OrderItem{
		PizzaId: pizzaId,
		Quantity: quantity,
	}
	// quantity must be positive
	if v.Quantity <= 0 {
		return OrderItem{}, fmt.Errorf("quantity must be positive")
	}
	return v, nil
}
