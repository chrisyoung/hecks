package memory

import (
	"sync"
	"governance_domain/domain"
)

type DeploymentMemoryRepository struct {
	mu    sync.RWMutex
	store map[string]*domain.Deployment
}

func NewDeploymentMemoryRepository() *DeploymentMemoryRepository {
	return &DeploymentMemoryRepository{store: make(map[string]*domain.Deployment)}
}

func (r *DeploymentMemoryRepository) Find(id string) (*domain.Deployment, error) {
	r.mu.RLock()
	defer r.mu.RUnlock()
	Deployment, ok := r.store[id]
	if !ok { return nil, nil }
	return Deployment, nil
}

func (r *DeploymentMemoryRepository) Save(Deployment *domain.Deployment) error {
	r.mu.Lock()
	defer r.mu.Unlock()
	r.store[Deployment.ID] = Deployment
	return nil
}

func (r *DeploymentMemoryRepository) All() ([]*domain.Deployment, error) {
	r.mu.RLock()
	defer r.mu.RUnlock()
	result := make([]*domain.Deployment, 0, len(r.store))
	for _, v := range r.store { result = append(result, v) }
	return result, nil
}

func (r *DeploymentMemoryRepository) Delete(id string) error {
	r.mu.Lock()
	defer r.mu.Unlock()
	delete(r.store, id)
	return nil
}

func (r *DeploymentMemoryRepository) Count() (int, error) {
	r.mu.RLock()
	defer r.mu.RUnlock()
	return len(r.store), nil
}
