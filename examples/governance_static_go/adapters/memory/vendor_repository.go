package memory

import (
	"sync"
	"governance_domain/domain"
)

type VendorMemoryRepository struct {
	mu    sync.RWMutex
	store map[string]*domain.Vendor
}

func NewVendorMemoryRepository() *VendorMemoryRepository {
	return &VendorMemoryRepository{store: make(map[string]*domain.Vendor)}
}

func (r *VendorMemoryRepository) Find(id string) (*domain.Vendor, error) {
	r.mu.RLock()
	defer r.mu.RUnlock()
	Vendor, ok := r.store[id]
	if !ok { return nil, nil }
	return Vendor, nil
}

func (r *VendorMemoryRepository) Save(Vendor *domain.Vendor) error {
	r.mu.Lock()
	defer r.mu.Unlock()
	r.store[Vendor.ID] = Vendor
	return nil
}

func (r *VendorMemoryRepository) All() ([]*domain.Vendor, error) {
	r.mu.RLock()
	defer r.mu.RUnlock()
	result := make([]*domain.Vendor, 0, len(r.store))
	for _, v := range r.store { result = append(result, v) }
	return result, nil
}

func (r *VendorMemoryRepository) Delete(id string) error {
	r.mu.Lock()
	defer r.mu.Unlock()
	delete(r.store, id)
	return nil
}

func (r *VendorMemoryRepository) Count() (int, error) {
	r.mu.RLock()
	defer r.mu.RUnlock()
	return len(r.store), nil
}
