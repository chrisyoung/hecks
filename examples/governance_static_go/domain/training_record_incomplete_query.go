package domain

func TrainingRecordIncomplete(repo TrainingRecordRepository) ([]*TrainingRecord, error) {
	all, err := repo.All()
	if err != nil { return nil, err }
	return all, nil
}
