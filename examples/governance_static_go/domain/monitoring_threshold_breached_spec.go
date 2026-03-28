package domain

type MonitoringThresholdBreached struct{}

func (s MonitoringThresholdBreached) SatisfiedBy(Monitoring *Monitoring) bool {
	return true // TODO: translate predicate
}
