package domain

func ByProvider(repo AiModelRepository, provider_id string) ([]*AiModel, error) {
	all, err := repo.All()
	if err != nil { return nil, err }
	var results []*AiModel
	for _, item := range all {
		if item.ProviderId == provider_id {
			results = append(results, item)
		}
	}
	return results, nil
}
