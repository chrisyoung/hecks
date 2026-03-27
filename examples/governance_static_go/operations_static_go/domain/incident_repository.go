package domain

type IncidentRepository interface {
	Find(id string) (*Incident, error)
	Save(Incident *Incident) error
	All() ([]*Incident, error)
	Delete(id string) error
	Count() (int, error)
}
