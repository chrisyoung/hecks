package domain

func ByStakeholder(repo TrainingRecordRepository, stakeholder_id string) ([]*TrainingRecord, error) {
	all, err := repo.All()
	if err != nil { return nil, err }
	var results []*TrainingRecord
	for _, item := range all {
		if item.StakeholderId == stakeholder_id {
			results = append(results, item)
		}
	}
	return results, nil
}
