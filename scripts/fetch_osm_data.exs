# Run with: mix run scripts/fetch_osm_data.exs

defmodule OSMDataFetcher do
  @moduledoc """
  Fetches real points of interest from OpenStreetMap for Nairobi
  Uses Overpass API - completely free and unlimited
  """
  
  alias Mtaani.Repo
  
  # Nairobi bounding box (approximate)
  @nairobi_bounds %{
    south: -1.45,
    north: -1.15,
    west: 36.65,
    east: 36.95
  }
  
  # Categories to fetch with their OSM tags
  @categories [
    %{
      name: "restaurant",
      tags: ["amenity=restaurant", "amenity=food_court", "amenity=cafe"],
      icon: "🍽️"
    },
    %{
      name: "attraction",
      tags: ["tourism=attraction", "tourism=museum", "tourism=gallery", "leisure=park"],
      icon: "🏛️"
    },
    %{
      name: "cafe",
      tags: ["amenity=cafe"],
      icon: "☕"
    },
    %{
      name: "hotel",
      tags: ["tourism=hotel", "tourism=hostel", "tourism=motel"],
      icon: "🏨"
    },
    %{
      name: "shopping",
      tags: ["shop=supermarket", "shop=mall", "shop=convenience"],
      icon: "🛍️"
    },
    %{
      name: "hospital",
      tags: ["amenity=hospital", "amenity=clinic", "amenity=doctors"],
      icon: "🏥"
    },
    %{
      name: "police",
      tags: ["amenity=police"],
      icon: "👮"
    },
    %{
      name: "atm",
      tags: ["amenity=atm"],
      icon: "💰"
    },
    %{
      name: "fuel",
      tags: ["amenity=fuel"],
      icon: "⛽"
    }
  ]
  
  def fetch_all do
    IO.puts("🌍 Fetching Nairobi POIs from OpenStreetMap...")
    
    for category <- @categories do
      fetch_category(category)
    end
    
    IO.puts("✅ All data fetched and saved!")
  end
  
  defp fetch_category(category) do
    IO.puts("  📍 Fetching #{category.name}...")
    
    # Build Overpass QL query
    query = build_overpass_query(category.tags, @nairobi_bounds)
    
    # Make request to Overpass API
    case HTTPoison.post("https://overpass-api.de/api/interpreter", query, [], timeout: 30_000) do
      {:ok, %HTTPoison.Response{status_code: 200, body: body}} ->
        parse_and_save(body, category)
        
      {:error, error} ->
        IO.puts("    ❌ Error fetching #{category.name}: #{inspect(error)}")
    end
  end
  
  defp build_overpass_query(tags, bounds) do
    """
    [out:json][timeout:25];
    (
      #{Enum.map(tags, fn tag -> "node[\"#{tag}\"](#{bounds.south},#{bounds.west},#{bounds.north},#{bounds.east});" end) |> Enum.join("\n      ")}
      #{Enum.map(tags, fn tag -> "way[\"#{tag}\"](#{bounds.south},#{bounds.west},#{bounds.north},#{bounds.east});" end) |> Enum.join("\n      ")}
    );
    out body;
    """
  end
  
  defp parse_and_save(body, category) do
    data = Jason.decode!(body)
    elements = data["elements"] || []
    
    count = 0
    for element <- elements do
      # Extract location
      location = cond do
        element["lat"] and element["lon"] -> "POINT(#{element["lon"]} #{element["lat"]})"
        element["center"] -> "POINT(#{element["center"]["lon"]} #{element["center"]["lat"]})"
        true -> nil
      end
      
      if location do
        name = get_name(element)
        address = get_address(element)
        phone = get_phone(element)
        website = get_website(element)
        
        # Insert into database
        insert_place(
          name,
          category.name,
          name || "Unknown",
          address,
          phone,
          website,
          location,
          category.icon
        )
        count = count + 1
      end
    end
    
    IO.puts("    ✅ Saved #{count} #{category.name} places")
  end
  
  defp get_name(element) do
    element["tags"]["name"] ||
    element["tags"]["brand"] ||
    element["tags"]["operator"] ||
    nil
  end
  
  defp get_address(element) do
    tags = element["tags"]
    parts = []
    parts = if tags["addr:street"], do: parts ++ [tags["addr:street"]], else: parts
    parts = if tags["addr:city"], do: parts ++ [tags["addr:city"]], else: parts
    parts = if tags["addr:full"], do: parts ++ [tags["addr:full"]], else: parts
    
    if Enum.empty?(parts), do: nil, else: Enum.join(parts, ", ")
  end
  
  defp get_phone(element) do
    element["tags"]["phone"] ||
    element["tags"]["contact:phone"] ||
    nil
  end
  
  defp get_website(element) do
    element["tags"]["website"] ||
    element["tags"]["contact:website"] ||
    nil
  end
  
  defp insert_place(name, category, description, address, phone, website, location, icon) do
    Repo.query!("""
      INSERT INTO places (name, category, description, address, phone, website, location, inserted_at, updated_at)
      VALUES ($1, $2, $3, $4, $5, $6, ST_GeomFromText($7, 4326), NOW(), NOW())
      ON CONFLICT DO NOTHING
    """, [name || "Unnamed", category, description, address, phone, website, location])
  end
end

# Run the fetcher
OSMDataFetcher.fetch_all()