package domain

func BySeverity(repo IncidentRepository, severity string) ([]*Incident, error) {
	all, err := repo.All()
	if err != nil { return nil, err }
	var results []*Incident
	for _, item := range all {
		if item.Severity == severity {
			results = append(results, item)
		}
	}
	return results, nil
}
