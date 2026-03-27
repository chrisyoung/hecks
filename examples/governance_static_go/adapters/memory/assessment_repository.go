package memory

import (
	"sync"
	"governance_domain/domain"
)

type AssessmentMemoryRepository struct {
	mu    sync.RWMutex
	store map[string]*domain.Assessment
}

func NewAssessmentMemoryRepository() *AssessmentMemoryRepository {
	return &AssessmentMemoryRepository{store: make(map[string]*domain.Assessment)}
}

func (r *AssessmentMemoryRepository) Find(id string) (*domain.Assessment, error) {
	r.mu.RLock()
	defer r.mu.RUnlock()
	Assessment, ok := r.store[id]
	if !ok { return nil, nil }
	return Assessment, nil
}

func (r *AssessmentMemoryRepository) Save(Assessment *domain.Assessment) error {
	r.mu.Lock()
	defer r.mu.Unlock()
	r.store[Assessment.ID] = Assessment
	return nil
}

func (r *AssessmentMemoryRepository) All() ([]*domain.Assessment, error) {
	r.mu.RLock()
	defer r.mu.RUnlock()
	result := make([]*domain.Assessment, 0, len(r.store))
	for _, v := range r.store { result = append(result, v) }
	return result, nil
}

func (r *AssessmentMemoryRepository) Delete(id string) error {
	r.mu.Lock()
	defer r.mu.Unlock()
	delete(r.store, id)
	return nil
}

func (r *AssessmentMemoryRepository) Count() (int, error) {
	r.mu.RLock()
	defer r.mu.RUnlock()
	return len(r.store), nil
}
