package memory

import (
	"sync"
	"operations_domain/domain"
)

type MonitoringMemoryRepository struct {
	mu    sync.RWMutex
	store map[string]*domain.Monitoring
}

func NewMonitoringMemoryRepository() *MonitoringMemoryRepository {
	return &MonitoringMemoryRepository{store: make(map[string]*domain.Monitoring)}
}

func (r *MonitoringMemoryRepository) Find(id string) (*domain.Monitoring, error) {
	r.mu.RLock()
	defer r.mu.RUnlock()
	Monitoring, ok := r.store[id]
	if !ok { return nil, nil }
	return Monitoring, nil
}

func (r *MonitoringMemoryRepository) Save(Monitoring *domain.Monitoring) error {
	r.mu.Lock()
	defer r.mu.Unlock()
	r.store[Monitoring.ID] = Monitoring
	return nil
}

func (r *MonitoringMemoryRepository) All() ([]*domain.Monitoring, error) {
	r.mu.RLock()
	defer r.mu.RUnlock()
	result := make([]*domain.Monitoring, 0, len(r.store))
	for _, v := range r.store { result = append(result, v) }
	return result, nil
}

func (r *MonitoringMemoryRepository) Delete(id string) error {
	r.mu.Lock()
	defer r.mu.Unlock()
	delete(r.store, id)
	return nil
}

func (r *MonitoringMemoryRepository) Count() (int, error) {
	r.mu.RLock()
	defer r.mu.RUnlock()
	return len(r.store), nil
}
