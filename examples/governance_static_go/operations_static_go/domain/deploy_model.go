package domain

import (
	"time"
	"fmt"
)

type DeployModel struct {
	DeploymentId string `json:"deployment_id"`
}

func (c DeployModel) CommandName() string { return "DeployModel" }

func (c DeployModel) Execute(repo DeploymentRepository) (*Deployment, *DeployedModel, error) {
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
	event := DeployedModel{
		AggregateID: existing.ID,
		DeploymentId: c.DeploymentId,
		OccurredAt: time.Now(),
	}
	return existing, &event, nil
}
