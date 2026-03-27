package domain

type GovernancePolicyRepository interface {
	Find(id string) (*GovernancePolicy, error)
	Save(GovernancePolicy *GovernancePolicy) error
	All() ([]*GovernancePolicy, error)
	Delete(id string) error
	Count() (int, error)
}
