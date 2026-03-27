package domain

func ByModel(repo AssessmentRepository, model_id string) ([]*Assessment, error) {
	all, err := repo.All()
	if err != nil { return nil, err }
	var results []*Assessment
	for _, item := range all {
		if item.ModelId == model_id {
			results = append(results, item)
		}
	}
	return results, nil
}
