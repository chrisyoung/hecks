package domain

type RegulatoryFrameworkRepository interface {
	Find(id string) (*RegulatoryFramework, error)
	Save(RegulatoryFramework *RegulatoryFramework) error
	All() ([]*RegulatoryFramework, error)
	Delete(id string) error
	Count() (int, error)
}
