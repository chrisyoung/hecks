Hecks.configure do
  domain "pizzas_domain"
  adapter :sql unless Rails.env.test?
end
