package domain

type TrainingRecordExpired struct{}

func (s TrainingRecordExpired) SatisfiedBy(TrainingRecord *TrainingRecord) bool {
	return true // TODO: translate predicate
}
