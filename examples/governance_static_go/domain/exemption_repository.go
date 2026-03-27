package domain

type ExemptionRepository interface {
	Find(id string) (*Exemption, error)
	Save(Exemption *Exemption) error
	All() ([]*Exemption, error)
	Delete(id string) error
	Count() (int, error)
}
