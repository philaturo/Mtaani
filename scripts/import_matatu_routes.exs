# Run with: mix run scripts/import_matatu_routes.exs
alias Mtaani.Repo
alias Mtaani.Transport.TransportProvider

# Import all routes
routes = MatatuRoutesData.all_routes()
saccos = MatatuRoutesData.saccos()
ride_hailing = MatatuRoutesData.ride_hailing()

# Clear existing data (optional)
Repo.delete_all(TransportProvider)

# Import matatu routes
for route <- routes do
  stages_coords = MatatuRoutesData.stages_coordinates()
  
  TransportProvider.create!(%{
    name: "#{route.sacco} - Route #{route.route_number}",
    type: route.vehicle_type,
    sacco_name: route.sacco,
    route_number: route.route_number,
    stages: route.stages,
    peak_hours: route.peak_hours,
    base_fare: route.base_fare || 50,
    price_per_km: route.price_per_km || 10,
    safety_score: route.safety_rating,
    verified: true,
    route_description: route.route_description,
    frequency_minutes: route.frequency_minutes,
    wheelchair_accessible: route.wheelchair_accessible
  })
end

IO.puts(" Imported #{length(routes)} matatu routes")

# Import ride-hailing services
for service <- ride_hailing do
  TransportProvider.create!(%{
    name: service.name,
    type: service.type,
    base_fare: service.base_fare,
    price_per_km: service.price_per_km,
    safety_score: service.safety_rating,
    verified: service.verified,
    logo_url: service.logo
  })
end

IO.puts(" Imported #{length(ride_hailing)} ride-hailing services")

# Update schema to include new fields
IO.puts("\n📊 Database Summary:")
IO.puts("- #{length(routes)} matatu routes")
IO.puts("- #{length(ride_hailing)} ride-hailing services")
IO.puts("- #{length(saccos)} Saccos")