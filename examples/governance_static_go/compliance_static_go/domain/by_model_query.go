package domain

func ByModel(repo ExemptionRepository, model_id string) ([]*Exemption, error) {
	all, err := repo.All()
	if err != nil { return nil, err }
	var results []*Exemption
	for _, item := range all {
		if item.ModelId == model_id {
			results = append(results, item)
		}
	}
	return results, nil
}
