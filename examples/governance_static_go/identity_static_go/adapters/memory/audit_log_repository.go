package memory

import (
	"sync"
	"identity_domain/domain"
)

type AuditLogMemoryRepository struct {
	mu    sync.RWMutex
	store map[string]*domain.AuditLog
}

func NewAuditLogMemoryRepository() *AuditLogMemoryRepository {
	return &AuditLogMemoryRepository{store: make(map[string]*domain.AuditLog)}
}

func (r *AuditLogMemoryRepository) Find(id string) (*domain.AuditLog, error) {
	r.mu.RLock()
	defer r.mu.RUnlock()
	AuditLog, ok := r.store[id]
	if !ok { return nil, nil }
	return AuditLog, nil
}

func (r *AuditLogMemoryRepository) Save(AuditLog *domain.AuditLog) error {
	r.mu.Lock()
	defer r.mu.Unlock()
	r.store[AuditLog.ID] = AuditLog
	return nil
}

func (r *AuditLogMemoryRepository) All() ([]*domain.AuditLog, error) {
	r.mu.RLock()
	defer r.mu.RUnlock()
	result := make([]*domain.AuditLog, 0, len(r.store))
	for _, v := range r.store { result = append(result, v) }
	return result, nil
}

func (r *AuditLogMemoryRepository) Delete(id string) error {
	r.mu.Lock()
	defer r.mu.Unlock()
	delete(r.store, id)
	return nil
}

func (r *AuditLogMemoryRepository) Count() (int, error) {
	r.mu.RLock()
	defer r.mu.RUnlock()
	return len(r.store), nil
}
