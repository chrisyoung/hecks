package domain

func GovernancePolicyByCategory(repo GovernancePolicyRepository, category string) ([]*GovernancePolicy, error) {
	all, err := repo.All()
	if err != nil { return nil, err }
	return all, nil
}
