package memory

import (
	"sync"
	"compliance_domain/domain"
)

type ComplianceReviewMemoryRepository struct {
	mu    sync.RWMutex
	store map[string]*domain.ComplianceReview
}

func NewComplianceReviewMemoryRepository() *ComplianceReviewMemoryRepository {
	return &ComplianceReviewMemoryRepository{store: make(map[string]*domain.ComplianceReview)}
}

func (r *ComplianceReviewMemoryRepository) Find(id string) (*domain.ComplianceReview, error) {
	r.mu.RLock()
	defer r.mu.RUnlock()
	ComplianceReview, ok := r.store[id]
	if !ok { return nil, nil }
	return ComplianceReview, nil
}

func (r *ComplianceReviewMemoryRepository) Save(ComplianceReview *domain.ComplianceReview) error {
	r.mu.Lock()
	defer r.mu.Unlock()
	r.store[ComplianceReview.ID] = ComplianceReview
	return nil
}

func (r *ComplianceReviewMemoryRepository) All() ([]*domain.ComplianceReview, error) {
	r.mu.RLock()
	defer r.mu.RUnlock()
	result := make([]*domain.ComplianceReview, 0, len(r.store))
	for _, v := range r.store { result = append(result, v) }
	return result, nil
}

func (r *ComplianceReviewMemoryRepository) Delete(id string) error {
	r.mu.Lock()
	defer r.mu.Unlock()
	delete(r.store, id)
	return nil
}

func (r *ComplianceReviewMemoryRepository) Count() (int, error) {
	r.mu.RLock()
	defer r.mu.RUnlock()
	return len(r.store), nil
}
