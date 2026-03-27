package domain

type CustomerFacing struct{}

func (s CustomerFacing) SatisfiedBy(Deployment *Deployment) bool {
	return true // TODO: translate predicate
}
