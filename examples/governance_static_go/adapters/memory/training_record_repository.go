package memory

import (
	"sync"
	"governance_domain/domain"
)

type TrainingRecordMemoryRepository struct {
	mu    sync.RWMutex
	store map[string]*domain.TrainingRecord
}

func NewTrainingRecordMemoryRepository() *TrainingRecordMemoryRepository {
	return &TrainingRecordMemoryRepository{store: make(map[string]*domain.TrainingRecord)}
}

func (r *TrainingRecordMemoryRepository) Find(id string) (*domain.TrainingRecord, error) {
	r.mu.RLock()
	defer r.mu.RUnlock()
	TrainingRecord, ok := r.store[id]
	if !ok { return nil, nil }
	return TrainingRecord, nil
}

func (r *TrainingRecordMemoryRepository) Save(TrainingRecord *domain.TrainingRecord) error {
	r.mu.Lock()
	defer r.mu.Unlock()
	r.store[TrainingRecord.ID] = TrainingRecord
	return nil
}

func (r *TrainingRecordMemoryRepository) All() ([]*domain.TrainingRecord, error) {
	r.mu.RLock()
	defer r.mu.RUnlock()
	result := make([]*domain.TrainingRecord, 0, len(r.store))
	for _, v := range r.store { result = append(result, v) }
	return result, nil
}

func (r *TrainingRecordMemoryRepository) Delete(id string) error {
	r.mu.Lock()
	defer r.mu.Unlock()
	delete(r.store, id)
	return nil
}

func (r *TrainingRecordMemoryRepository) Count() (int, error) {
	r.mu.RLock()
	defer r.mu.RUnlock()
	return len(r.store), nil
}
