package domain

func Pending(repo OrderRepository) ([]*Order, error) {
	all, err := repo.All()
	if err != nil { return nil, err }
	var results []*Order
	for _, item := range all {
		if item.Status == "pending" {
			results = append(results, item)
		}
	}
	return results, nil
}
