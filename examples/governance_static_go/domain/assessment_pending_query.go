package domain

func AssessmentPending(repo AssessmentRepository) ([]*Assessment, error) {
	all, err := repo.All()
	if err != nil { return nil, err }
	return all, nil
}
