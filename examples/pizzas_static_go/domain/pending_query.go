package domain

// Pending query for Order
// Generated from DSL query definition
func Pending(repo OrderRepository) ([]*Order, error) {
	all, err := repo.All()
	if err != nil { return nil, err }
	var results []*Order
	for _, item := range all {
		// TODO: filter logic from DSL block
		results = append(results, item)
	}
	return results, nil
}
