package domain

func Active(repo DataUsageAgreementRepository) ([]*DataUsageAgreement, error) {
	all, err := repo.All()
	if err != nil { return nil, err }
	var results []*DataUsageAgreement
	for _, item := range all {
		if item.Status == "active" {
			results = append(results, item)
		}
	}
	return results, nil
}
