package domain

import "time"

type RecordedMetric struct {
	AggregateID string    `json:"aggregate_id"`
	AggregateId string `json:"aggregate_id"`
	ModelId string `json:"model_id"`
	DeploymentId string `json:"deployment_id"`
	MetricName string `json:"metric_name"`
	Value float64 `json:"value"`
	Threshold float64 `json:"threshold"`
	RecordedAt time.Time `json:"recorded_at"`
	OccurredAt time.Time `json:"occurred_at"`
}

func (e RecordedMetric) EventName() string { return "RecordedMetric" }

func (e RecordedMetric) GetOccurredAt() time.Time { return e.OccurredAt }
