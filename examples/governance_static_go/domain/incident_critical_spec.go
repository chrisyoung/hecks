package domain

type IncidentCritical struct{}

func (s IncidentCritical) SatisfiedBy(Incident *Incident) bool {
	return true // TODO: translate predicate
}
