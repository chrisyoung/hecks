package domain

func Active(repo StakeholderRepository) ([]*Stakeholder, error) {
	all, err := repo.All()
	if err != nil { return nil, err }
	var results []*Stakeholder
	for _, item := range all {
		if item.Status == "active" {
			results = append(results, item)
		}
	}
	return results, nil
}
