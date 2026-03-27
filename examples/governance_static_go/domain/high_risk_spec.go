package domain

type HighRisk struct{}

func (s HighRisk) SatisfiedBy(AiModel *AiModel) bool {
	return AiModel.RiskLevel == "high" || AiModel.RiskLevel == "critical"
}
