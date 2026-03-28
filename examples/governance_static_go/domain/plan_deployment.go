package domain

import (
	"time"
)

type PlanDeployment struct {
	ModelId string `json:"model_id"`
	Environment string `json:"environment"`
	Endpoint string `json:"endpoint"`
	Purpose string `json:"purpose"`
	Audience string `json:"audience"`
}

func (c PlanDeployment) CommandName() string { return "PlanDeployment" }

func (c PlanDeployment) Execute(repo DeploymentRepository) (*Deployment, *PlannedDeployment, error) {
	agg := NewDeployment(c.ModelId, c.Environment, c.Endpoint, c.Purpose, c.Audience, time.Time{}, time.Time{}, "")
	agg.Status = "planned"
	if err := agg.Validate(); err != nil {
		return nil, nil, err
	}
	if err := repo.Save(agg); err != nil {
		return nil, nil, err
	}
	event := PlannedDeployment{
		AggregateID: agg.ID,
		ModelId: c.ModelId,
		Environment: c.Environment,
		Endpoint: c.Endpoint,
		Purpose: c.Purpose,
		Audience: c.Audience,
		OccurredAt: time.Now(),
	}
	return agg, &event, nil
}
