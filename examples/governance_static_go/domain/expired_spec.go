package domain

type Expired struct{}

func (s Expired) SatisfiedBy(DataUsageAgreement *DataUsageAgreement) bool {
	return true // TODO: translate predicate
}
