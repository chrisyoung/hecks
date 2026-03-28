package domain

import (
	"time"
	"github.com/google/uuid"
	"fmt"
)

type Deployment struct {
	ID string `json:"id"`
	CreatedAt time.Time `json:"created_at"`
	UpdatedAt time.Time `json:"updated_at"`
	ModelId string `json:"model_id"`
	Environment string `json:"environment"`
	Endpoint string `json:"endpoint"`
	Purpose string `json:"purpose"`
	Audience string `json:"audience"`
	DeployedAt time.Time `json:"deployed_at"`
	DecommissionedAt time.Time `json:"decommissioned_at"`
	Status string `json:"status"`
}

func NewDeployment(modelId string, environment string, endpoint string, purpose string, audience string, deployedAt time.Time, decommissionedAt time.Time, status string) *Deployment {
	a := &Deployment{
		ID:        uuid.New().String(),
		ModelId: modelId,
		Environment: environment,
		Endpoint: endpoint,
		Purpose: purpose,
		Audience: audience,
		DeployedAt: deployedAt,
		DecommissionedAt: decommissionedAt,
		Status: status,
		CreatedAt: time.Now(),
		UpdatedAt: time.Now(),
	}
	return a
}

func (a *Deployment) Validate() error {
	if a.ModelId == "" {
		return &ValidationError{Field: "model_id", Message: "model_id can't be blank"}
	}
	if a.Environment == "" {
		return &ValidationError{Field: "environment", Message: "environment can't be blank"}
	}
	if a.Environment != "" {
		validEnvironment := map[string]bool{"development": true, "staging": true, "production": true}
		if !validEnvironment[a.Environment] {
			return &ValidationError{Field: "environment", Message: fmt.Sprintf("environment must be one of: development, staging, production, got: %s", a.Environment)}
		}
	}
	if a.Audience != "" {
		validAudience := map[string]bool{"internal": true, "customer-facing": true, "public": true}
		if !validAudience[a.Audience] {
			return &ValidationError{Field: "audience", Message: fmt.Sprintf("audience must be one of: internal, customer-facing, public, got: %s", a.Audience)}
		}
	}
	return nil
}
