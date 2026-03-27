package domain

import (
	"time"
	"fmt"
)

type DecommissionDeployment struct {
	DeploymentId string `json:"deployment_id"`
}

func (c DecommissionDeployment) CommandName() string { return "DecommissionDeployment" }

func (c DecommissionDeployment) Execute(repo DeploymentRepository) (*Deployment, *DecommissionedDeployment, error) {
	existing, err := repo.Find(c.DeploymentId)
	if err != nil {
		return nil, nil, err
	}
	if existing == nil {
		return nil, nil, fmt.Errorf("Deployment not found: %s", c.DeploymentId)
	}
	existing.UpdatedAt = time.Now()
	if err := existing.Validate(); err != nil {
		return nil, nil, err
	}
	if err := repo.Save(existing); err != nil {
		return nil, nil, err
	}
	event := DecommissionedDeployment{
		AggregateID: existing.ID,
		DeploymentId: c.DeploymentId,
		OccurredAt: time.Now(),
	}
	return existing, &event, nil
}
