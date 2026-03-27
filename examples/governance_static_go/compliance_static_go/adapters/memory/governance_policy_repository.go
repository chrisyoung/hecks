package memory

import (
	"sync"
	"compliance_domain/domain"
)

type GovernancePolicyMemoryRepository struct {
	mu    sync.RWMutex
	store map[string]*domain.GovernancePolicy
}

func NewGovernancePolicyMemoryRepository() *GovernancePolicyMemoryRepository {
	return &GovernancePolicyMemoryRepository{store: make(map[string]*domain.GovernancePolicy)}
}

func (r *GovernancePolicyMemoryRepository) Find(id string) (*domain.GovernancePolicy, error) {
	r.mu.RLock()
	defer r.mu.RUnlock()
	GovernancePolicy, ok := r.store[id]
	if !ok { return nil, nil }
	return GovernancePolicy, nil
}

func (r *GovernancePolicyMemoryRepository) Save(GovernancePolicy *domain.GovernancePolicy) error {
	r.mu.Lock()
	defer r.mu.Unlock()
	r.store[GovernancePolicy.ID] = GovernancePolicy
	return nil
}

func (r *GovernancePolicyMemoryRepository) All() ([]*domain.GovernancePolicy, error) {
	r.mu.RLock()
	defer r.mu.RUnlock()
	result := make([]*domain.GovernancePolicy, 0, len(r.store))
	for _, v := range r.store { result = append(result, v) }
	return result, nil
}

func (r *GovernancePolicyMemoryRepository) Delete(id string) error {
	r.mu.Lock()
	defer r.mu.Unlock()
	delete(r.store, id)
	return nil
}

func (r *GovernancePolicyMemoryRepository) Count() (int, error) {
	r.mu.RLock()
	defer r.mu.RUnlock()
	return len(r.store), nil
}
