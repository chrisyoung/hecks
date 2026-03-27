package domain

type Critical struct{}

func (s Critical) SatisfiedBy(Incident *Incident) bool {
	return true // TODO: translate predicate
}
