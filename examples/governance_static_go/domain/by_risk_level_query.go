package domain

func ByRiskLevel(repo AiModelRepository, level string) ([]*AiModel, error) {
	all, err := repo.All()
	if err != nil { return nil, err }
	return all, nil
}
