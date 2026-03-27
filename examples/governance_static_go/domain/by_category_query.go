package domain

func ByCategory(repo GovernancePolicyRepository, category string) ([]*GovernancePolicy, error) {
	all, err := repo.All()
	if err != nil { return nil, err }
	var results []*GovernancePolicy
	for _, item := range all {
		if item.Category == category {
			results = append(results, item)
		}
	}
	return results, nil
}
