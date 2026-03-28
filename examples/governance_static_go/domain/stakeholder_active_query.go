package domain

func StakeholderActive(repo StakeholderRepository) ([]*Stakeholder, error) {
	all, err := repo.All()
	if err != nil { return nil, err }
	return all, nil
}
