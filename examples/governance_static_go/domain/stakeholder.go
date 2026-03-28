package domain

import (
	"time"
	"github.com/google/uuid"
	"fmt"
)

type Stakeholder struct {
	ID string `json:"id"`
	CreatedAt time.Time `json:"created_at"`
	UpdatedAt time.Time `json:"updated_at"`
	Name string `json:"name"`
	Email string `json:"email"`
	Role string `json:"role"`
	Team string `json:"team"`
	Status string `json:"status"`
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
	if a.Name == "" {
		return &ValidationError{Field: "name", Message: "name can't be blank"}
	}
	if a.Email == "" {
		return &ValidationError{Field: "email", Message: "email can't be blank"}
	}
	if a.Role != "" {
		validRole := map[string]bool{"assessor": true, "reviewer": true, "governance_board": true, "data_steward": true, "incident_reporter": true, "admin": true, "auditor": true}
		if !validRole[a.Role] {
			return &ValidationError{Field: "role", Message: fmt.Sprintf("role must be one of: assessor, reviewer, governance_board, data_steward, incident_reporter, admin, auditor, got: %s", a.Role)}
		}
	}
	return nil
}
