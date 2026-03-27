package domain

func Pending(repo ComplianceReviewRepository) ([]*ComplianceReview, error) {
	all, err := repo.All()
	if err != nil { return nil, err }
	var results []*ComplianceReview
	for _, item := range all {
		if item.Status == "open" {
			results = append(results, item)
		}
	}
	return results, nil
}
