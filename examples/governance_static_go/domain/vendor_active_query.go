package domain

func VendorActive(repo VendorRepository) ([]*Vendor, error) {
	all, err := repo.All()
	if err != nil { return nil, err }
	return all, nil
}
