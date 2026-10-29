extends RefCounted
var grid := AStarGrid2D.new()
var walkable: Array[Vector2i] = []

func configure(points: Array) -> void:
 var polygon := PackedVector2Array()
 for point in points:
  polygon.append(Vector2(point[0], point[1]))
 grid.region = Rect2i(0, 0, 46, 18)
 grid.cell_size = Vector2(0.02, 0.01)
 grid.offset = Vector2(0.05, 0.60)
 grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
 grid.update()
 walkable.clear()
 for x in range(46):
  for y in range(18):
   var id := Vector2i(x, y)
   var inside := Geometry2D.is_point_in_polygon(grid.get_point_position(id), polygon)
   grid.set_point_solid(id, not inside)
   if inside:
    walkable.append(id)

func nearest(point: Vector2) -> Vector2i:
 var best := Vector2i.ZERO
 var distance := INF
 for id in walkable:
  var candidate := point.distance_squared_to(grid.get_point_position(id))
  if candidate < distance:
   best = id
   distance = candidate
 return best

func path(from: Vector2, destination: Vector2) -> PackedVector2Array:
 if walkable.is_empty():
  return PackedVector2Array()
 return grid.get_point_path(nearest(from), nearest(destination))
