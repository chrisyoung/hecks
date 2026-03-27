package memory

import (
	"sync"
	"governance_domain/domain"
)

type IncidentMemoryRepository struct {
	mu    sync.RWMutex
	store map[string]*domain.Incident
}

func NewIncidentMemoryRepository() *IncidentMemoryRepository {
	return &IncidentMemoryRepository{store: make(map[string]*domain.Incident)}
}

func (r *IncidentMemoryRepository) Find(id string) (*domain.Incident, error) {
	r.mu.RLock()
	defer r.mu.RUnlock()
	Incident, ok := r.store[id]
	if !ok { return nil, nil }
	return Incident, nil
}

func (r *IncidentMemoryRepository) Save(Incident *domain.Incident) error {
	r.mu.Lock()
	defer r.mu.Unlock()
	r.store[Incident.ID] = Incident
	return nil
}

func (r *IncidentMemoryRepository) All() ([]*domain.Incident, error) {
	r.mu.RLock()
	defer r.mu.RUnlock()
	result := make([]*domain.Incident, 0, len(r.store))
	for _, v := range r.store { result = append(result, v) }
	return result, nil
}

func (r *IncidentMemoryRepository) Delete(id string) error {
	r.mu.Lock()
	defer r.mu.Unlock()
	delete(r.store, id)
	return nil
}

func (r *IncidentMemoryRepository) Count() (int, error) {
	r.mu.RLock()
	defer r.mu.RUnlock()
	return len(r.store), nil
}
