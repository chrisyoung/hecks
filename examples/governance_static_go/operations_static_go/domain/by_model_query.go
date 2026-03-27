package domain

func ByModel(repo MonitoringRepository, model_id string) ([]*Monitoring, error) {
	all, err := repo.All()
	if err != nil { return nil, err }
	var results []*Monitoring
	for _, item := range all {
		if item.ModelId == model_id {
			results = append(results, item)
		}
	}
	return results, nil
}
