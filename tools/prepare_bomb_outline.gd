extends SceneTree
func _initialize() -> void:
    var source := Image.load_from_file("res://assets/template/bombs/puff_bomb.webp")
    var mask := BitMap.new()
    mask.create_from_image_alpha(source,0.4)
    var polygons := mask.opaque_to_polygons(Rect2i(Vector2i.ZERO,source.get_size()),12.0)
    var largest := PackedVector2Array()
    var largest_area := 0.0
    for polygon in polygons:
        var area := 0.0
        for index in range(polygon.size()): area += polygon[index].cross(polygon[(index+1)%polygon.size()])
        if absf(area) > largest_area:
            largest_area = absf(area)
            largest = polygon
    var points := []
    for point in largest: points.append([snappedf(point.x/source.get_width()-0.5,0.00001),snappedf(point.y/source.get_height()-0.5,0.00001)])
    var file := FileAccess.open("res://assets/template/bombs/manifest.json",FileAccess.WRITE)
    file.store_string(JSON.stringify({"key":"puff_bomb","size":[source.get_width(),source.get_height()],"outline":points},"  ")+"\n")
    print("Bomb silhouette vertices: ",points.size())
    quit(0 if points.size() >= 8 else 1)
