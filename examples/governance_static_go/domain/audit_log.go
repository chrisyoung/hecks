package domain

import (
	"time"
	"github.com/google/uuid"
)

type AuditLog struct {
	ID        string    `json:"id"`
	EntityType string `json:"entity_type"`
	EntityId string `json:"entity_id"`
	Action string `json:"action"`
	ActorId string `json:"actor_id"`
	Details string `json:"details"`
	Timestamp time.Time `json:"timestamp"`
	CreatedAt time.Time `json:"created_at"`
	UpdatedAt time.Time `json:"updated_at"`
}

func NewAuditLog(entityType string, entityId string, action string, actorId string, details string, timestamp time.Time) *AuditLog {
	a := &AuditLog{
		ID:        uuid.New().String(),
		EntityType: entityType,
		EntityId: entityId,
		Action: action,
		ActorId: actorId,
		Details: details,
		Timestamp: timestamp,
		CreatedAt: time.Now(),
		UpdatedAt: time.Now(),
	}
	return a
}

func (a *AuditLog) Validate() error {
	return nil
}
