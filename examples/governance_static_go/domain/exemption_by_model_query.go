package domain

func ExemptionByModel(repo ExemptionRepository, model_id string) ([]*Exemption, error) {
	all, err := repo.All()
	if err != nil { return nil, err }
	return all, nil
}
