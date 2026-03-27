package domain

import (
	"time"
	"github.com/google/uuid"
)

type Monitoring struct {
	ID        string    `json:"id"`
	ModelId string `json:"model_id"`
	DeploymentId string `json:"deployment_id"`
	MetricName string `json:"metric_name"`
	Value float64 `json:"value"`
	Threshold float64 `json:"threshold"`
	RecordedAt time.Time `json:"recorded_at"`
	CreatedAt time.Time `json:"created_at"`
	UpdatedAt time.Time `json:"updated_at"`
}

func NewMonitoring(modelId string, deploymentId string, metricName string, value float64, threshold float64, recordedAt time.Time) *Monitoring {
	a := &Monitoring{
		ID:        uuid.New().String(),
		ModelId: modelId,
		DeploymentId: deploymentId,
		MetricName: metricName,
		Value: value,
		Threshold: threshold,
		RecordedAt: recordedAt,
		CreatedAt: time.Now(),
		UpdatedAt: time.Now(),
	}
	return a
}

func (a *Monitoring) Validate() error {
	if a.ModelId == "" {
		return &ValidationError{Field: "model_id", Message: "model_id can't be blank"}
	}
	if a.MetricName == "" {
		return &ValidationError{Field: "metric_name", Message: "metric_name can't be blank"}
	}
	// invariant: threshold must be positive
	return nil
}
