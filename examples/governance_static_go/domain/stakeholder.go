package domain

import (
	"time"
	"github.com/google/uuid"
)

type Stakeholder struct {
	ID        string    `json:"id"`
	Name string `json:"name"`
	Email string `json:"email"`
	Role string `json:"role"`
	Team string `json:"team"`
	Status string `json:"status"`
	CreatedAt time.Time `json:"created_at"`
	UpdatedAt time.Time `json:"updated_at"`
}

func NewStakeholder(name string, email string, role string, team string, status string) *Stakeholder {
	a := &Stakeholder{
		ID:        uuid.New().String(),
		Name: name,
		Email: email,
		Role: role,
		Team: team,
		Status: status,
		CreatedAt: time.Now(),
		UpdatedAt: time.Now(),
	}
	return a
}

func (a *Stakeholder) Validate() error {
	return nil
}
