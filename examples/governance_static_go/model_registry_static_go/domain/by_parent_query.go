package domain

func ByParent(repo AiModelRepository, parent_id string) ([]*AiModel, error) {
	all, err := repo.All()
	if err != nil { return nil, err }
	var results []*AiModel
	for _, item := range all {
		if item.ParentModelId == parent_id {
			results = append(results, item)
		}
	}
	return results, nil
}
