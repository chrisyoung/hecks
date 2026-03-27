package domain

func ByRiskLevel(repo AiModelRepository, level string) ([]*AiModel, error) {
	all, err := repo.All()
	if err != nil { return nil, err }
	var results []*AiModel
	for _, item := range all {
		if item.RiskLevel == level {
			results = append(results, item)
		}
	}
	return results, nil
}
