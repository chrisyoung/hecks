package domain

func ByRole(repo StakeholderRepository, role string) ([]*Stakeholder, error) {
	all, err := repo.All()
	if err != nil { return nil, err }
	var results []*Stakeholder
	for _, item := range all {
		if item.Role == role {
			results = append(results, item)
		}
	}
	return results, nil
}
