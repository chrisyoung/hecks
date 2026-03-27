package domain

func Pending(repo AssessmentRepository) ([]*Assessment, error) {
	all, err := repo.All()
	if err != nil { return nil, err }
	var results []*Assessment
	for _, item := range all {
		if item.Status == "pending" {
			results = append(results, item)
		}
	}
	return results, nil
}
