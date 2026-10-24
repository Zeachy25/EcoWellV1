-- =====================================================================
-- EcoWell | green_spaces | Replace with 3 polygon locations + add address
-- Run in Supabase: SQL Editor -> New query -> paste -> Run
-- =====================================================================

-- 1) Re-declare RPC with address (must drop due to return type change)
drop function if exists public.get_green_spaces();

create function public.get_green_spaces()
returns table (
  id                 uuid,
  name               text,
  description        text,
  category           text,
  address            text,
  photo_url          text,
  lat                double precision,
  lng                double precision,
  boundary_geojson   jsonb,
  quiet_score_avg    numeric,
  quiet_rating_count bigint
)
language sql
stable
as $$
  select g.id,
         g.name,
         g.description,
         g.category,
         g.address,
         g.photo_url,
         st_y(g.center::geometry),
         st_x(g.center::geometry),
         st_asgeojson(g.boundary::geometry)::jsonb,
         gs.quiet_score_avg,
         gs.quiet_rating_count
  from public.green_spaces g
  left join public.green_spaces_with_stats gs on gs.id = g.id
  order by g.name;
$$;

grant execute on function public.get_green_spaces() to anon, authenticated;

-- 2) Wipe existing places and related social/check-in data
truncate table public.green_spaces cascade;

-- 3) Insert the 3 new locations
insert into public.green_spaces (name, description, category, address, boundary, center)
select
  v.name,
  v.description,
  v.category,
  v.address,
  st_setsrid(st_geomfromgeojson(v.boundary_geojson), 4326)::geography,
  st_setsrid(st_makepoint(v.lng::double precision, v.lat::double precision), 4326)::geography
from (values
  -- Mini Forest
  ('Mini Forest',
   'A small pocket of shade and birdsong in Martinez, Dahican — an easy place to clear your head after a busy day of classes.',
   'garden',
   'Martinez, Dahican, Mati City, Davao Oriental',
   '{"type":"Polygon","coordinates":[[[126.2532563,6.9323749],[126.2533498,6.9324359],[126.2534378,6.9323246],[126.2535766,6.9324147],[126.2536434,6.9323405],[126.2537875,6.9324518],[126.2537288,6.9325074],[126.2540197,6.9327273],[126.254276,6.932412],[126.2537128,6.9319616],[126.2536113,6.932102],[126.2535259,6.9320463],[126.2532563,6.9323749]]]}',
   126.2538097, 6.9323311),

  -- test Loc.
  ('test Loc.',
   'A short trail through the Tate neighbourhood in Dahican — a few quiet minutes on the way home.',
   'trail',
   'Urban Poor, Dahican, Mati City, Davao Oriental',
   '{"type":"Polygon","coordinates":[[[126.2584993,6.9305754],[126.2584787,6.9305524],[126.2584993,6.9305308],[126.2585185,6.9305588],[126.2584993,6.9305754]]]}',
   126.2584988, 6.9305539),

  -- Guang-Guang Mangrove Park (using your hand-drawn polygon)
  ('Guang-Guang Mangrove Park',
   'A quiet stand of mangroves on the edge of the Guang-Guang flats, where the sea breeze and the birds make it easy to slow down.',
   'mangrove',
   'Guang-Guang Urban Poor Dahican, Mati City, Davao Oriental',
   '{"type":"Polygon","coordinates":[[[126.2587458,6.9183024],[126.2595033,6.9186078],[126.2596588,6.9184567],[126.2598871,6.9186045],[126.2608563,6.9178295],[126.2606909,6.9170216],[126.2593379,6.9177211],[126.2589476,6.9179838],[126.2587458,6.9183024]]]}',
   126.2599120, 6.9179123)
) as v(name, description, category, address, boundary_geojson, lng, lat);
