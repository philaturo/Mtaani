defmodule MatatuRoutesData do
  @moduledoc """
  Complete Nairobi Matatu Routes Database
  Sources: Tuko.co.ke, Ma3Route, Kenya Urban Roads Authority
  Last updated: April 2026
  """

  # Full routes data structure
  def all_routes do
    [
      # ========== CBD TERMINUS ROUTES ==========
      %{
        route_number: "11",
        sacco: "City Hoppa",
        terminus: "Kencom",
        stages: ["Kencom", "KNH", "Kenyatta National Hospital", "Mbagathi", "Kenyatta National Hospital", "Kencom"],
        route_description: "CBD to KNH via Mbagathi Road",
        peak_hours: ["6:00-9:00", "16:00-19:00"],
        frequency_minutes: 5,
        vehicle_type: "matatu",
        safety_rating: 4.2,
        wheelchair_accessible: false
      },
      %{
        route_number: "44",
        sacco: "Super Metro",
        terminus: "Kencom",
        stages: ["Kencom", "Westlands", "Kangemi", "Uthiru", "Kikuyu", "Uthiru", "Kencom"],
        route_description: "CBD to Kikuyu via Waiyaki Way",
        peak_hours: ["6:00-9:00", "16:00-20:00"],
        frequency_minutes: 3,
        vehicle_type: "matatu",
        safety_rating: 4.8,
        wheelchair_accessible: false
      },
      %{
        route_number: "46",
        sacco: "Citi Hoppa",
        terminus: "Kencom",
        stages: ["Kencom", "Kawangware", "Kileleshwa", "Kawangware", "Kencom"],
        route_description: "CBD to Kawangware via Kileleshwa",
        peak_hours: ["6:00-10:00", "15:00-20:00"],
        frequency_minutes: 4,
        vehicle_type: "matatu",
        safety_rating: 4.3,
        wheelchair_accessible: false
      },
      %{
        route_number: "58",
        sacco: "Kenya Bus Service",
        terminus: "Kencom",
        stages: ["Kencom", "Kibera", "Laini Saba", "Kibera", "Kencom"],
        route_description: "CBD to Kibera via Langata Road",
        peak_hours: ["6:00-20:00"],
        frequency_minutes: 7,
        vehicle_type: "bus",
        safety_rating: 3.8,
        wheelchair_accessible: true
      },
      %{
        route_number: "125",
        sacco: "Super Metro",
        terminus: "Kencom",
        stages: ["Kencom", "Ruiru", "Juja", "Githurai", "Ruiru", "Kencom"],
        route_description: "CBD to Ruiru via Thika Road",
        peak_hours: ["5:00-9:00", "16:00-21:00"],
        frequency_minutes: 4,
        vehicle_type: "matatu",
        safety_rating: 4.5,
        wheelchair_accessible: false
      },
      %{
        route_number: "33",
        sacco: "Nyahururu",
        terminus: "Kencom",
        stages: ["Kencom", "Ngong", "Karen", "Ngong", "Kencom"],
        route_description: "CBD to Karen via Ngong Road",
        peak_hours: ["6:00-8:00", "17:00-19:00"],
        frequency_minutes: 6,
        vehicle_type: "matatu",
        safety_rating: 4.0,
        wheelchair_accessible: false
      },
      %{
        route_number: "7",
        sacco: "KBS",
        terminus: "Kencom",
        stages: ["Kencom", "Eastlands", "Umoja", "Embakasi", "Eastlands", "Kencom"],
        route_description: "CBD to Embakasi via Jogoo Road",
        peak_hours: ["6:00-9:00", "16:00-20:00"],
        frequency_minutes: 5,
        vehicle_type: "bus",
        safety_rating: 4.1,
        wheelchair_accessible: true
      },
      %{
        route_number: "8",
        sacco: "KBS",
        terminus: "Kencom",
        stages: ["Kencom", "Industrial Area", "South B", "South C", "Industrial Area", "Kencom"],
        route_description: "CBD to South B/C via Mombasa Road",
        peak_hours: ["6:00-9:00", "16:00-19:00"],
        frequency_minutes: 6,
        vehicle_type: "bus",
        safety_rating: 4.0,
        wheelchair_accessible: true
      },
      %{
        route_number: "15",
        sacco: "City Shuttle",
        terminus: "Kencom",
        stages: ["Kencom", "Parklands", "Westlands", "Parklands", "Kencom"],
        route_description: "CBD to Parklands via Limuru Road",
        peak_hours: ["7:00-9:00", "17:00-19:00"],
        frequency_minutes: 5,
        vehicle_type: "matatu",
        safety_rating: 4.3,
        wheelchair_accessible: false
      },
      %{
        route_number: "23",
        sacco: "Super Metro",
        terminus: "Kencom",
        stages: ["Kencom", "Donholm", "Pipeline", "Donholm", "Kencom"],
        route_description: "CBD to Pipeline via Jogoo Road",
        peak_hours: ["5:30-9:00", "16:00-21:00"],
        frequency_minutes: 4,
        vehicle_type: "matatu",
        safety_rating: 4.6,
        wheelchair_accessible: false
      },
      
      # ========== RAILWAYS TERMINUS ROUTES ==========
      %{
        route_number: "110",
        sacco: "Citi Hoppa",
        terminus: "Railways",
        stages: ["Railways", "Ngong Road", "Karen", "Ngong Road", "Railways"],
        route_description: "Railways to Karen via Ngong Road",
        peak_hours: ["6:00-9:00", "16:00-19:00"],
        frequency_minutes: 5,
        vehicle_type: "matatu",
        safety_rating: 4.2,
        wheelchair_accessible: false
      },
      %{
        route_number: "111",
        sacco: "Citi Hoppa",
        terminus: "Railways",
        stages: ["Railways", "Langata", "Bomas", "Langata", "Railways"],
        route_description: "Railways to Bomas via Langata Road",
        peak_hours: ["6:00-9:00", "16:00-19:00"],
        frequency_minutes: 5,
        vehicle_type: "matatu",
        safety_rating: 4.1,
        wheelchair_accessible: false
      },
      %{
        route_number: "112",
        sacco: "Citi Hoppa",
        terminus: "Railways",
        stages: ["Railways", "Madaraka", "Kibera", "Madaraka", "Railways"],
        route_description: "Railways to Kibera via Madaraka",
        peak_hours: ["6:00-20:00"],
        frequency_minutes: 6,
        vehicle_type: "matatu",
        safety_rating: 3.9,
        wheelchair_accessible: false
      },
      
      # ========== EASTLANDS ROUTES ==========
      %{
        route_number: "17",
        sacco: "KBS",
        terminus: "Eastlands",
        stages: ["Eastlands", "Buruburu", "Donholm", "Eastlands"],
        route_description: "Buruburu to Donholm loop",
        peak_hours: ["5:30-9:00", "16:00-20:00"],
        frequency_minutes: 4,
        vehicle_type: "bus",
        safety_rating: 4.2,
        wheelchair_accessible: true
      },
      %{
        route_number: "19",
        sacco: "KBS",
        terminus: "Eastlands",
        stages: ["Eastlands", "Umoja", "Kariobangi", "Eastlands"],
        route_description: "Umoja to Kariobangi loop",
        peak_hours: ["5:30-9:00", "16:00-20:00"],
        frequency_minutes: 5,
        vehicle_type: "bus",
        safety_rating: 4.0,
        wheelchair_accessible: true
      },
      %{
        route_number: "25",
        sacco: "Super Metro",
        terminus: "Eastlands",
        stages: ["Eastlands", "Tena", "Embakasi", "Tena", "Eastlands"],
        route_description: "Eastlands to Embakasi via Tena",
        peak_hours: ["5:00-9:00", "16:00-21:00"],
        frequency_minutes: 4,
        vehicle_type: "matatu",
        safety_rating: 4.4,
        wheelchair_accessible: false
      },
      %{
        route_number: "27",
        sacco: "Super Metro",
        terminus: "Eastlands",
        stages: ["Eastlands", "Komarock", "Tena", "Komarock", "Eastlands"],
        route_description: "Eastlands to Komarock via Tena",
        peak_hours: ["5:00-9:00", "16:00-21:00"],
        frequency_minutes: 4,
        vehicle_type: "matatu",
        safety_rating: 4.5,
        wheelchair_accessible: false
      },
      
      # ========== WESTLANDS ROUTES ==========
      %{
        route_number: "48",
        sacco: "City Shuttle",
        terminus: "Westlands",
        stages: ["Westlands", "Lavington", "Kilimani", "Lavington", "Westlands"],
        route_description: "Westlands to Kilimani via Lavington",
        peak_hours: ["7:00-10:00", "16:00-19:00"],
        frequency_minutes: 5,
        vehicle_type: "matatu",
        safety_rating: 4.3,
        wheelchair_accessible: false
      },
      %{
        route_number: "52",
        sacco: "Citi Hoppa",
        terminus: "Westlands",
        stages: ["Westlands", "Kileleshwa", "Kileleshwa", "Westlands"],
        route_description: "Westlands to Kileleshwa loop",
        peak_hours: ["6:00-9:00", "16:00-19:00"],
        frequency_minutes: 5,
        vehicle_type: "matatu",
        safety_rating: 4.4,
        wheelchair_accessible: false
      },
      
      # ========== KAWANGWARE ROUTES ==========
      %{
        route_number: "36",
        sacco: "Citi Hoppa",
        terminus: "Kawangware",
        stages: ["Kawangware", "Muthangari", "Kileleshwa", "Muthangari", "Kawangware"],
        route_description: "Kawangware to Kileleshwa via Muthangari",
        peak_hours: ["6:00-9:00", "16:00-19:00"],
        frequency_minutes: 5,
        vehicle_type: "matatu",
        safety_rating: 3.8,
        wheelchair_accessible: false
      },
      %{
        route_number: "37",
        sacco: "City Hoppa",
        terminus: "Kawangware",
        stages: ["Kawangware", "Kangemi", "Uthiru", "Kangemi", "Kawangware"],
        route_description: "Kawangware to Uthiru via Kangemi",
        peak_hours: ["6:00-9:00", "16:00-19:00"],
        frequency_minutes: 6,
        vehicle_type: "matatu",
        safety_rating: 3.9,
        wheelchair_accessible: false
      },
      
      # ========== KIKUYU ROUTES ==========
      %{
        route_number: "103",
        sacco: "Super Metro",
        terminus: "Kikuyu",
        stages: ["Kikuyu", "Kangemi", "Uthiru", "Kangemi", "Kikuyu"],
        route_description: "Kikuyu to CBD via Kangemi",
        peak_hours: ["5:00-8:00", "16:00-20:00"],
        frequency_minutes: 4,
        vehicle_type: "matatu",
        safety_rating: 4.5,
        wheelchair_accessible: false
      },
      %{
        route_number: "104",
        sacco: "Super Metro",
        terminus: "Kikuyu",
        stages: ["Kikuyu", "Ndenderu", "Gitaru", "Ndenderu", "Kikuyu"],
        route_description: "Kikuyu to Ndenderu via Gitaru",
        peak_hours: ["5:30-8:00", "16:00-19:00"],
        frequency_minutes: 5,
        vehicle_type: "matatu",
        safety_rating: 4.3,
        wheelchair_accessible: false
      }
    ]
  end
  
  # Sacco information
  def saccos do
    [
      %{name: "Super Metro", safety_rating: 4.8, description: "Premium matatu service with excellent safety record", verified: true},
      %{name: "Citi Hoppa", safety_rating: 4.3, description: "Reliable service across major routes", verified: true},
      %{name: "City Hoppa", safety_rating: 4.2, description: "Popular choice for Eastlands routes", verified: true},
      %{name: "City Shuttle", safety_rating: 4.2, description: "Good service for Westlands and Parklands", verified: true},
      %{name: "Kenya Bus Service (KBS)", safety_rating: 4.0, description: "Government bus service, wheelchair accessible", verified: true},
      %{name: "Nyahururu", safety_rating: 3.8, description: "Budget option for Karen route", verified: true}
    ]
  end
  
  # Ride-hailing services
  def ride_hailing do
    [
      %{name: "Uber", type: "taxi", base_fare: 200, price_per_km: 100, safety_rating: 4.8, verified: true, logo: "uber.png"},
      %{name: "Bolt", type: "taxi", base_fare: 180, price_per_km: 90, safety_rating: 4.6, verified: true, logo: "bolt.png"},
      %{name: "Little Cab", type: "taxi", base_fare: 190, price_per_km: 95, safety_rating: 4.7, verified: true, logo: "little.png"},
      %{name: "Yego", type: "boda", base_fare: 100, price_per_km: 50, safety_rating: 4.5, verified: true, logo: "yego.png"},
      %{name: "SafeBoda", type: "boda", base_fare: 100, price_per_km: 55, safety_rating: 4.6, verified: true, logo: "safeboda.png"},
      %{name: "Farasi Cab", type: "taxi", base_fare: 150, price_per_km: 85, safety_rating: 4.4, verified: true, logo: "farasi.png"}
    ]
  end
  
  # Stages with coordinates (for map display)
  def stages_coordinates do
    %{
      "Kencom" => [-1.2889, 36.8234],
      "KNH" => [-1.3000, 36.8250],
      "Westlands" => [-1.2645, 36.8015],
      "Kangemi" => [-1.2580, 36.7770],
      "Uthiru" => [-1.2500, 36.7650],
      "Kikuyu" => [-1.2450, 36.6700],
      "Kawangware" => [-1.2750, 36.7800],
      "Kileleshwa" => [-1.2850, 36.7900],
      "Kibera" => [-1.3150, 36.7900],
      "Ruiru" => [-1.1450, 36.9600],
      "Juja" => [-1.1020, 37.0130],
      "Karen" => [-1.3260, 36.7120],
      "Ngong" => [-1.3640, 36.6350],
      "Donholm" => [-1.2830, 36.8670],
      "Pipeline" => [-1.2720, 36.8820],
      "Umoja" => [-1.2900, 36.9000],
      "Embakasi" => [-1.3100, 36.8800],
      "Komarock" => [-1.2910, 36.9100],
      "Buruburu" => [-1.2950, 36.8550],
      "Lavington" => [-1.2820, 36.7870],
      "Kilimani" => [-1.2920, 36.7890],
      "Industrial Area" => [-1.3100, 36.8400],
      "South B" => [-1.3050, 36.8200],
      "South C" => [-1.3000, 36.8150],
      "Parklands" => [-1.2670, 36.8190]
    }
  end
end