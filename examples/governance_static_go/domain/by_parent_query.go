package domain

func ByParent(repo AiModelRepository, parent_id string) ([]*AiModel, error) {
	all, err := repo.All()
	if err != nil { return nil, err }
	return all, nil
}
