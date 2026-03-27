package domain

type MonitoringRepository interface {
	Find(id string) (*Monitoring, error)
	Save(Monitoring *Monitoring) error
	All() ([]*Monitoring, error)
	Delete(id string) error
	Count() (int, error)
}
