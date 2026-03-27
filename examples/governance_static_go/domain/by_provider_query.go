package domain

func ByProvider(repo AiModelRepository, provider_id string) ([]*AiModel, error) {
	all, err := repo.All()
	if err != nil { return nil, err }
	return all, nil
}
