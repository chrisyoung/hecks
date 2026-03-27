package domain

func ByModel(repo DataUsageAgreementRepository, model_id string) ([]*DataUsageAgreement, error) {
	all, err := repo.All()
	if err != nil { return nil, err }
	var results []*DataUsageAgreement
	for _, item := range all {
		if item.ModelId == model_id {
			results = append(results, item)
		}
	}
	return results, nil
}
