package domain

func TrainingRecordByStakeholder(repo TrainingRecordRepository, stakeholder_id string) ([]*TrainingRecord, error) {
	all, err := repo.All()
	if err != nil { return nil, err }
	return all, nil
}
