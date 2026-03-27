package memory

import (
	"sync"
	"governance_domain/domain"
)

type DataUsageAgreementMemoryRepository struct {
	mu    sync.RWMutex
	store map[string]*domain.DataUsageAgreement
}

func NewDataUsageAgreementMemoryRepository() *DataUsageAgreementMemoryRepository {
	return &DataUsageAgreementMemoryRepository{store: make(map[string]*domain.DataUsageAgreement)}
}

func (r *DataUsageAgreementMemoryRepository) Find(id string) (*domain.DataUsageAgreement, error) {
	r.mu.RLock()
	defer r.mu.RUnlock()
	DataUsageAgreement, ok := r.store[id]
	if !ok { return nil, nil }
	return DataUsageAgreement, nil
}

func (r *DataUsageAgreementMemoryRepository) Save(DataUsageAgreement *domain.DataUsageAgreement) error {
	r.mu.Lock()
	defer r.mu.Unlock()
	r.store[DataUsageAgreement.ID] = DataUsageAgreement
	return nil
}

func (r *DataUsageAgreementMemoryRepository) All() ([]*domain.DataUsageAgreement, error) {
	r.mu.RLock()
	defer r.mu.RUnlock()
	result := make([]*domain.DataUsageAgreement, 0, len(r.store))
	for _, v := range r.store { result = append(result, v) }
	return result, nil
}

func (r *DataUsageAgreementMemoryRepository) Delete(id string) error {
	r.mu.Lock()
	defer r.mu.Unlock()
	delete(r.store, id)
	return nil
}

func (r *DataUsageAgreementMemoryRepository) Count() (int, error) {
	r.mu.RLock()
	defer r.mu.RUnlock()
	return len(r.store), nil
}
