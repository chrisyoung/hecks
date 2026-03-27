package domain

type DeploymentRepository interface {
	Find(id string) (*Deployment, error)
	Save(Deployment *Deployment) error
	All() ([]*Deployment, error)
	Delete(id string) error
	Count() (int, error)
}
