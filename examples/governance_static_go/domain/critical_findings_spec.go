package domain

type CriticalFindings struct{}

func (s CriticalFindings) SatisfiedBy(Assessment *Assessment) bool {
	return true // TODO: translate predicate
}
