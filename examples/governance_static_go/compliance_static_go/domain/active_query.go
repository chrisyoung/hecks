package domain

func Active(repo ExemptionRepository) ([]*Exemption, error) {
	all, err := repo.All()
	if err != nil { return nil, err }
	var results []*Exemption
	for _, item := range all {
		if item.Status == "active" {
			results = append(results, item)
		}
	}
	return results, nil
}
