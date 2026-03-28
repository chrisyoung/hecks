package domain

func StakeholderByRole(repo StakeholderRepository, role string) ([]*Stakeholder, error) {
	all, err := repo.All()
	if err != nil { return nil, err }
	return all, nil
}
