package memory

import (
	"sync"
	"governance_domain/domain"
)

type ExemptionMemoryRepository struct {
	mu    sync.RWMutex
	store map[string]*domain.Exemption
}

func NewExemptionMemoryRepository() *ExemptionMemoryRepository {
	return &ExemptionMemoryRepository{store: make(map[string]*domain.Exemption)}
}

func (r *ExemptionMemoryRepository) Find(id string) (*domain.Exemption, error) {
	r.mu.RLock()
	defer r.mu.RUnlock()
	Exemption, ok := r.store[id]
	if !ok { return nil, nil }
	return Exemption, nil
}

func (r *ExemptionMemoryRepository) Save(Exemption *domain.Exemption) error {
	r.mu.Lock()
	defer r.mu.Unlock()
	r.store[Exemption.ID] = Exemption
	return nil
}

func (r *ExemptionMemoryRepository) All() ([]*domain.Exemption, error) {
	r.mu.RLock()
	defer r.mu.RUnlock()
	result := make([]*domain.Exemption, 0, len(r.store))
	for _, v := range r.store { result = append(result, v) }
	return result, nil
}

func (r *ExemptionMemoryRepository) Delete(id string) error {
	r.mu.Lock()
	defer r.mu.Unlock()
	delete(r.store, id)
	return nil
}

func (r *ExemptionMemoryRepository) Count() (int, error) {
	r.mu.RLock()
	defer r.mu.RUnlock()
	return len(r.store), nil
}
