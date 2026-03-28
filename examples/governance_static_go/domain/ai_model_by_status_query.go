package domain

func AiModelByStatus(repo AiModelRepository, status string) ([]*AiModel, error) {
	all, err := repo.All()
	if err != nil { return nil, err }
	return all, nil
}
