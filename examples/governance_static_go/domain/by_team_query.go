package domain

func ByTeam(repo StakeholderRepository, team string) ([]*Stakeholder, error) {
	all, err := repo.All()
	if err != nil { return nil, err }
	return all, nil
}
