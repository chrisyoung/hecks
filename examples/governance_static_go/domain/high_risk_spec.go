package domain

type HighRisk struct{}

func (s HighRisk) SatisfiedBy(AiModel *AiModel) bool {
	return true // TODO: translate predicate
}
