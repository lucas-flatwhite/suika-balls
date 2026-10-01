extends RefCounted

# One world-pixel contour tolerance; protected hull vertices keep every flat
# support plane exact at every rotation. Cache decomposition, not just decoding.
const CONTOUR_TOLERANCE := 1.0
static var cache: Dictionary = {}

static func geometry(texture: Texture2D,render_size: Vector2) -> Dictionary:
    if not render_size.is_finite() or render_size.x <= 0.0 or render_size.y <= 0.0:
        return _fallback(Vector2.ONE,"render size must be finite and positive")
    if texture == null:
        return _fallback(render_size,"texture is null")
    var key := "%s:%s" % [texture.get_instance_id(),render_size]
    if cache.has(key): return cache[key]
    var image := texture.get_image()
    if image == null or image.is_empty():
        return _fallback(render_size,"texture has no readable image")
    if image.is_compressed() and image.decompress() != OK:
        return _fallback(render_size,"texture image cannot be decompressed")
    var mask := BitMap.new()
    mask.create_from_image_alpha(image,0.0)
    var polygons := mask.opaque_to_polygons(Rect2i(Vector2i.ZERO,image.get_size()),0.0)
    var contour := PackedVector2Array()
    var largest_area := 0.0
    for polygon in polygons:
        var area := 0.0
        for index in polygon.size(): area += polygon[index].cross(polygon[(index+1)%polygon.size()])
        if absf(area)>largest_area:
            largest_area = absf(area)
            contour = polygon
    if contour.size() < 3 or largest_area <= 0.0:
        return _fallback(render_size,"texture has no non-transparent silhouette")
    var size := texture.get_size()
    for index in contour.size():
        contour[index] = (contour[index]/size-Vector2.ONE*0.5)*render_size
    var hull := Geometry2D.convex_hull(contour)
    var anchors: Array[int] = []
    for point in hull:
        var index := contour.find(point)
        if index >= 0 and not index in anchors: anchors.append(index)
    anchors.sort()
    var outline := PackedVector2Array()
    for index in anchors.size():
        var first := anchors[index]
        var last := anchors[(index+1)%anchors.size()]
        if last <= first: last += contour.size()
        var segment := PackedVector2Array()
        for cursor in range(first,last+1): segment.append(contour[cursor%contour.size()])
        var simplified := _simplify(segment)
        simplified.resize(simplified.size()-1)
        outline.append_array(simplified)
    if outline.size() < 3:
        return _fallback(render_size,"simplified silhouette has fewer than three vertices")
    var pieces := Geometry2D.decompose_polygon_in_convex(outline)
    if pieces.is_empty():
        return _fallback(render_size,"silhouette cannot be decomposed into collision pieces")
    var result := {"texture":texture,"outline":outline,"pieces":pieces,"error":""}
    cache[key] = result
    return result

static func _simplify(points: PackedVector2Array) -> PackedVector2Array:
    if points.size() <= 2: return points
    var split := -1
    var furthest := CONTOUR_TOLERANCE
    for index in range(1,points.size()-1):
        var nearest := Geometry2D.get_closest_point_to_segment(points[index],points[0],points[-1])
        var distance := points[index].distance_to(nearest)
        if distance > furthest:
            furthest = distance
            split = index
    if split < 0: return PackedVector2Array([points[0],points[-1]])
    var result := _simplify(points.slice(0,split+1))
    result.resize(result.size()-1)
    result.append_array(_simplify(points.slice(split)))
    return result

static func _fallback(render_size: Vector2,reason: String) -> Dictionary:
    # Callers report the diagnostic; retain solid collision while replacement
    # artwork is repaired instead of silently dropping actors through the board.
    var half := render_size * 0.5
    var outline := PackedVector2Array([Vector2(-half.x,-half.y),Vector2(half.x,-half.y),half,Vector2(-half.x,half.y)])
    return {"outline":outline,"pieces":[outline],"error":reason}
