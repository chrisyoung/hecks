package domain

import (
	"time"
)

type RecordMetric struct {
	ModelId string `json:"model_id"`
	DeploymentId string `json:"deployment_id"`
	MetricName string `json:"metric_name"`
	Value float64 `json:"value"`
	Threshold float64 `json:"threshold"`
}

func (c RecordMetric) CommandName() string { return "RecordMetric" }

func (c RecordMetric) Execute(repo MonitoringRepository) (*Monitoring, *RecordedMetric, error) {
	agg := NewMonitoring(c.ModelId, c.DeploymentId, c.MetricName, c.Value, c.Threshold, time.Time{})
	if err := agg.Validate(); err != nil {
		return nil, nil, err
	}
	if err := repo.Save(agg); err != nil {
		return nil, nil, err
	}
	event := RecordedMetric{
		AggregateID: agg.ID,
		ModelId: c.ModelId,
		DeploymentId: c.DeploymentId,
		MetricName: c.MetricName,
		Value: c.Value,
		Threshold: c.Threshold,
		OccurredAt: time.Now(),
	}
	return agg, &event, nil
}
