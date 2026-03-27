package domain

func ByReviewer(repo ComplianceReviewRepository, reviewer_id string) ([]*ComplianceReview, error) {
	all, err := repo.All()
	if err != nil { return nil, err }
	var results []*ComplianceReview
	for _, item := range all {
		if item.ReviewerId == reviewer_id {
			results = append(results, item)
		}
	}
	return results, nil
}
