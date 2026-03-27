package domain

import "time"

type PlannedDeployment struct {
	AggregateID string    `json:"aggregate_id"`
	AggregateId string `json:"aggregate_id"`
	ModelId string `json:"model_id"`
	Environment string `json:"environment"`
	Endpoint string `json:"endpoint"`
	Purpose string `json:"purpose"`
	Audience string `json:"audience"`
	DeployedAt time.Time `json:"deployed_at"`
	DecommissionedAt time.Time `json:"decommissioned_at"`
	Status string `json:"status"`
	OccurredAt time.Time `json:"occurred_at"`
}

func (e PlannedDeployment) EventName() string { return "PlannedDeployment" }

func (e PlannedDeployment) GetOccurredAt() time.Time { return e.OccurredAt }
