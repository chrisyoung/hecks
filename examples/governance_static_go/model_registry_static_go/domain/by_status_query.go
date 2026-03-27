package domain

func ByStatus(repo AiModelRepository, status string) ([]*AiModel, error) {
	all, err := repo.All()
	if err != nil { return nil, err }
	var results []*AiModel
	for _, item := range all {
		if item.Status == status {
			results = append(results, item)
		}
	}
	return results, nil
}
