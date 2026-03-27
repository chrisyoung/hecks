package domain

import "time"

type SetThresholdEvent struct {
	AggregateID string    `json:"aggregate_id"`
	AggregateId string `json:"aggregate_id"`
	MonitoringId string `json:"monitoring_id"`
	Threshold float64 `json:"threshold"`
	ModelId string `json:"model_id"`
	DeploymentId string `json:"deployment_id"`
	MetricName string `json:"metric_name"`
	Value float64 `json:"value"`
	RecordedAt time.Time `json:"recorded_at"`
	OccurredAt time.Time `json:"occurred_at"`
}

func (e SetThresholdEvent) EventName() string { return "SetThreshold" }

func (e SetThresholdEvent) GetOccurredAt() time.Time { return e.OccurredAt }
