package domain

type StakeholderRepository interface {
	Find(id string) (*Stakeholder, error)
	Save(Stakeholder *Stakeholder) error
	All() ([]*Stakeholder, error)
	Delete(id string) error
	Count() (int, error)
}
