package domain

func ComplianceReviewPending(repo ComplianceReviewRepository) ([]*ComplianceReview, error) {
	all, err := repo.All()
	if err != nil { return nil, err }
	return all, nil
}
