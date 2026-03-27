package domain

func ByReviewer(repo ComplianceReviewRepository, reviewer_id string) ([]*ComplianceReview, error) {
	all, err := repo.All()
	if err != nil { return nil, err }
	return all, nil
}
