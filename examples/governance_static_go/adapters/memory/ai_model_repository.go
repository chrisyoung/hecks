package memory

import (
	"sync"
	"governance_domain/domain"
)

type AiModelMemoryRepository struct {
	mu    sync.RWMutex
	store map[string]*domain.AiModel
}

func NewAiModelMemoryRepository() *AiModelMemoryRepository {
	return &AiModelMemoryRepository{store: make(map[string]*domain.AiModel)}
}

func (r *AiModelMemoryRepository) Find(id string) (*domain.AiModel, error) {
	r.mu.RLock()
	defer r.mu.RUnlock()
	AiModel, ok := r.store[id]
	if !ok { return nil, nil }
	return AiModel, nil
}

func (r *AiModelMemoryRepository) Save(AiModel *domain.AiModel) error {
	r.mu.Lock()
	defer r.mu.Unlock()
	r.store[AiModel.ID] = AiModel
	return nil
}

func (r *AiModelMemoryRepository) All() ([]*domain.AiModel, error) {
	r.mu.RLock()
	defer r.mu.RUnlock()
	result := make([]*domain.AiModel, 0, len(r.store))
	for _, v := range r.store { result = append(result, v) }
	return result, nil
}

func (r *AiModelMemoryRepository) Delete(id string) error {
	r.mu.Lock()
	defer r.mu.Unlock()
	delete(r.store, id)
	return nil
}

func (r *AiModelMemoryRepository) Count() (int, error) {
	r.mu.RLock()
	defer r.mu.RUnlock()
	return len(r.store), nil
}
