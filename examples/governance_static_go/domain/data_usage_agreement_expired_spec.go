package domain

type DataUsageAgreementExpired struct{}

func (s DataUsageAgreementExpired) SatisfiedBy(DataUsageAgreement *DataUsageAgreement) bool {
	return true // TODO: translate predicate
}
