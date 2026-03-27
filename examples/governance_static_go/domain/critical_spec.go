package domain

type Critical struct{}

func (s Critical) SatisfiedBy(Incident *Incident) bool {
	return Incident.Severity == "critical" || Incident.Category == "safety"
}
