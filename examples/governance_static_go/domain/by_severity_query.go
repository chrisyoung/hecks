package domain

func BySeverity(repo IncidentRepository, severity string) ([]*Incident, error) {
	all, err := repo.All()
	if err != nil { return nil, err }
	return all, nil
}
