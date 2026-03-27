package memory

import (
	"sync"
	"identity_domain/domain"
)

type StakeholderMemoryRepository struct {
	mu    sync.RWMutex
	store map[string]*domain.Stakeholder
}

func NewStakeholderMemoryRepository() *StakeholderMemoryRepository {
	return &StakeholderMemoryRepository{store: make(map[string]*domain.Stakeholder)}
}

func (r *StakeholderMemoryRepository) Find(id string) (*domain.Stakeholder, error) {
	r.mu.RLock()
	defer r.mu.RUnlock()
	Stakeholder, ok := r.store[id]
	if !ok { return nil, nil }
	return Stakeholder, nil
}

func (r *StakeholderMemoryRepository) Save(Stakeholder *domain.Stakeholder) error {
	r.mu.Lock()
	defer r.mu.Unlock()
	r.store[Stakeholder.ID] = Stakeholder
	return nil
}

func (r *StakeholderMemoryRepository) All() ([]*domain.Stakeholder, error) {
	r.mu.RLock()
	defer r.mu.RUnlock()
	result := make([]*domain.Stakeholder, 0, len(r.store))
	for _, v := range r.store { result = append(result, v) }
	return result, nil
}

func (r *StakeholderMemoryRepository) Delete(id string) error {
	r.mu.Lock()
	defer r.mu.Unlock()
	delete(r.store, id)
	return nil
}

func (r *StakeholderMemoryRepository) Count() (int, error) {
	r.mu.RLock()
	defer r.mu.RUnlock()
	return len(r.store), nil
}
