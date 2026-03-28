package domain

func IncidentByModel(repo IncidentRepository, model_id string) ([]*Incident, error) {
	all, err := repo.All()
	if err != nil { return nil, err }
	return all, nil
}
