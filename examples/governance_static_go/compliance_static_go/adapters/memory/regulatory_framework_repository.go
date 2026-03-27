package memory

import (
	"sync"
	"compliance_domain/domain"
)

type RegulatoryFrameworkMemoryRepository struct {
	mu    sync.RWMutex
	store map[string]*domain.RegulatoryFramework
}

func NewRegulatoryFrameworkMemoryRepository() *RegulatoryFrameworkMemoryRepository {
	return &RegulatoryFrameworkMemoryRepository{store: make(map[string]*domain.RegulatoryFramework)}
}

func (r *RegulatoryFrameworkMemoryRepository) Find(id string) (*domain.RegulatoryFramework, error) {
	r.mu.RLock()
	defer r.mu.RUnlock()
	RegulatoryFramework, ok := r.store[id]
	if !ok { return nil, nil }
	return RegulatoryFramework, nil
}

func (r *RegulatoryFrameworkMemoryRepository) Save(RegulatoryFramework *domain.RegulatoryFramework) error {
	r.mu.Lock()
	defer r.mu.Unlock()
	r.store[RegulatoryFramework.ID] = RegulatoryFramework
	return nil
}

func (r *RegulatoryFrameworkMemoryRepository) All() ([]*domain.RegulatoryFramework, error) {
	r.mu.RLock()
	defer r.mu.RUnlock()
	result := make([]*domain.RegulatoryFramework, 0, len(r.store))
	for _, v := range r.store { result = append(result, v) }
	return result, nil
}

func (r *RegulatoryFrameworkMemoryRepository) Delete(id string) error {
	r.mu.Lock()
	defer r.mu.Unlock()
	delete(r.store, id)
	return nil
}

func (r *RegulatoryFrameworkMemoryRepository) Count() (int, error) {
	r.mu.RLock()
	defer r.mu.RUnlock()
	return len(r.store), nil
}
