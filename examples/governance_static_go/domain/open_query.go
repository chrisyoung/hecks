package domain

func Open(repo IncidentRepository) ([]*Incident, error) {
	all, err := repo.All()
	if err != nil { return nil, err }
	var results []*Incident
	for _, item := range all {
		if item.Status == "reported" {
			results = append(results, item)
		}
	}
	return results, nil
}
