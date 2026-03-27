package domain

type ThresholdBreached struct{}

func (s ThresholdBreached) SatisfiedBy(Monitoring *Monitoring) bool {
	return true // TODO: translate predicate
}
