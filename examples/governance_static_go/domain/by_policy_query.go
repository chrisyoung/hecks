package domain

func ByPolicy(repo TrainingRecordRepository, policy_id string) ([]*TrainingRecord, error) {
	all, err := repo.All()
	if err != nil { return nil, err }
	var results []*TrainingRecord
	for _, item := range all {
		if item.PolicyId == policy_id {
			results = append(results, item)
		}
	}
	return results, nil
}
