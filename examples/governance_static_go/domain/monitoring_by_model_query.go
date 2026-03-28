package domain

func MonitoringByModel(repo MonitoringRepository, model_id string) ([]*Monitoring, error) {
	all, err := repo.All()
	if err != nil { return nil, err }
	return all, nil
}
