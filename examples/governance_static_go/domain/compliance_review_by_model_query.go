package domain

func ComplianceReviewByModel(repo ComplianceReviewRepository, model_id string) ([]*ComplianceReview, error) {
	all, err := repo.All()
	if err != nil { return nil, err }
	return all, nil
}
