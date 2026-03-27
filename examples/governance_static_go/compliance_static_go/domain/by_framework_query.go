package domain

func ByFramework(repo GovernancePolicyRepository, framework_id string) ([]*GovernancePolicy, error) {
	all, err := repo.All()
	if err != nil { return nil, err }
	var results []*GovernancePolicy
	for _, item := range all {
		if item.FrameworkId == framework_id {
			results = append(results, item)
		}
	}
	return results, nil
}
