package domain

import "time"

type RecordedEntry struct {
	AggregateID string    `json:"aggregate_id"`
	AggregateId string `json:"aggregate_id"`
	EntityType string `json:"entity_type"`
	EntityId string `json:"entity_id"`
	Action string `json:"action"`
	ActorId string `json:"actor_id"`
	Details string `json:"details"`
	Timestamp time.Time `json:"timestamp"`
	OccurredAt time.Time `json:"occurred_at"`
}

func (e RecordedEntry) EventName() string { return "RecordedEntry" }

func (e RecordedEntry) GetOccurredAt() time.Time { return e.OccurredAt }
