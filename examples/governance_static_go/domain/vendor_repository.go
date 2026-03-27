package domain

type VendorRepository interface {
	Find(id string) (*Vendor, error)
	Save(Vendor *Vendor) error
	All() ([]*Vendor, error)
	Delete(id string) error
	Count() (int, error)
}
