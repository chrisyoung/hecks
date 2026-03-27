package domain

func ByTeam(repo StakeholderRepository, team string) ([]*Stakeholder, error) {
	all, err := repo.All()
	if err != nil { return nil, err }
	var results []*Stakeholder
	for _, item := range all {
		if item.Team == team {
			results = append(results, item)
		}
	}
	return results, nil
}
