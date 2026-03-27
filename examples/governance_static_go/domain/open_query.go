package domain

func Open(repo IncidentRepository) ([]*Incident, error) {
	all, err := repo.All()
	if err != nil { return nil, err }
	return all, nil
}
