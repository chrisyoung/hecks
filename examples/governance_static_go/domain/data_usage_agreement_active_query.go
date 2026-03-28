package domain

func DataUsageAgreementActive(repo DataUsageAgreementRepository) ([]*DataUsageAgreement, error) {
	all, err := repo.All()
	if err != nil { return nil, err }
	return all, nil
}
