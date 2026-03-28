package domain

func DataUsageAgreementByModel(repo DataUsageAgreementRepository, model_id string) ([]*DataUsageAgreement, error) {
	all, err := repo.All()
	if err != nil { return nil, err }
	return all, nil
}
