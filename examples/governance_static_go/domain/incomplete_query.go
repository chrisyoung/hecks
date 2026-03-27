package domain

func Incomplete(repo TrainingRecordRepository) ([]*TrainingRecord, error) {
	all, err := repo.All()
	if err != nil { return nil, err }
	var results []*TrainingRecord
	for _, item := range all {
		if item.Status == "assigned" {
			results = append(results, item)
		}
	}
	return results, nil
}
