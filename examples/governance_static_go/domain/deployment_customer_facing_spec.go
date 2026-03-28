package domain

type DeploymentCustomerFacing struct{}

func (s DeploymentCustomerFacing) SatisfiedBy(Deployment *Deployment) bool {
	return true // TODO: translate predicate
}
