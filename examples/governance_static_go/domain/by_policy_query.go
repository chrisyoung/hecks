package domain

func ByPolicy(repo TrainingRecordRepository, policy_id string) ([]*TrainingRecord, error) {
	all, err := repo.All()
	if err != nil { return nil, err }
	return all, nil
}
