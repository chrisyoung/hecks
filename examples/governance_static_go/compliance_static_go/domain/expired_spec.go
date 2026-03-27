package domain

type Expired struct{}

func (s Expired) SatisfiedBy(TrainingRecord *TrainingRecord) bool {
	return true // TODO: translate predicate
}
