package domain

type AiModelHighRisk struct{}

func (s AiModelHighRisk) SatisfiedBy(AiModel *AiModel) bool {
	return true // TODO: translate predicate
}
