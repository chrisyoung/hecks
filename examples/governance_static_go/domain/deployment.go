package domain

import (
	"time"
	"github.com/google/uuid"
)

type Deployment struct {
	ID        string    `json:"id"`
	ModelId string `json:"model_id"`
	Environment string `json:"environment"`
	Endpoint string `json:"endpoint"`
	Purpose string `json:"purpose"`
	Audience string `json:"audience"`
	DeployedAt time.Time `json:"deployed_at"`
	DecommissionedAt time.Time `json:"decommissioned_at"`
	Status string `json:"status"`
	CreatedAt time.Time `json:"created_at"`
	UpdatedAt time.Time `json:"updated_at"`
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
	return nil
}
