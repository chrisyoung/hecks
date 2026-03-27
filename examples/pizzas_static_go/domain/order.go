package domain

import (
	"time"
	"github.com/google/uuid"
)

type Order struct {
	ID        string    `json:"id"`
	CustomerName string `json:"customer_name"`
	Items []Orderitem `json:"items"`
	Status string `json:"status"`
	CreatedAt time.Time `json:"created_at"`
	UpdatedAt time.Time `json:"updated_at"`
}

func NewOrder(customerName string, items []Orderitem, status string) *Order {
	a := &Order{
		ID:        uuid.New().String(),
		CustomerName: customerName,
		Items: items,
		Status: status,
		CreatedAt: time.Now(),
		UpdatedAt: time.Now(),
	}
	return a
}

func (a *Order) Validate() error {
	if a.CustomerName == "" {
		return &ValidationError{Field: "customer_name", Message: "customer_name can't be blank"}
	}
	return nil
}

func (a *Order) IsPending() bool { return a.Status == "pending" }
func (a *Order) IsCancelled() bool { return a.Status == "cancelled" }
