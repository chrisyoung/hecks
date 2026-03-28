package domain

type ExemptionExpired struct{}

func (s ExemptionExpired) SatisfiedBy(Exemption *Exemption) bool {
	return true // TODO: translate predicate
}
