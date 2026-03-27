package domain

func ByModel(repo AssessmentRepository, model_id string) ([]*Assessment, error) {
	all, err := repo.All()
	if err != nil { return nil, err }
	return all, nil
}
