package domain

import (
	"time"
)

type RecordEntry struct {
	EntityType string `json:"entity_type"`
	EntityId string `json:"entity_id"`
	Action string `json:"action"`
	ActorId string `json:"actor_id"`
	Details string `json:"details"`
}

func (c RecordEntry) CommandName() string { return "RecordEntry" }

func (c RecordEntry) Execute(repo AuditLogRepository) (*AuditLog, *RecordedEntry, error) {
	agg := NewAuditLog(c.EntityType, c.EntityId, c.Action, c.ActorId, c.Details, time.Time{})
	if err := agg.Validate(); err != nil {
		return nil, nil, err
	}
	if err := repo.Save(agg); err != nil {
		return nil, nil, err
	}
	event := RecordedEntry{
		AggregateID: agg.ID,
		EntityType: c.EntityType,
		EntityId: c.EntityId,
		Action: c.Action,
		ActorId: c.ActorId,
		Details: c.Details,
		OccurredAt: time.Now(),
	}
	return agg, &event, nil
}
