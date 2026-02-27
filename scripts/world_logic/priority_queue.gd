class_name PriorityQueue

var _heap: Array = []

func push(item, priority: float):
    _heap.append({"item": item, "priority": priority})
    _bubble_up(_heap.size() - 1)

func pop():
    if _heap.is_empty(): return null
    var top = _heap[0].item
    var last = _heap.pop_back()
    if not _heap.is_empty():
        _heap[0] = last
        _sink_down(0)
    return top

func peek():
    return _heap[0].item if not _heap.is_empty() else null

func is_empty() -> bool:
    return _heap.is_empty()

func size() -> int:
    return _heap.size()

func _bubble_up(i: int):
    while i > 0:
        var parent = (i - 1) / 2
        if _heap[parent].priority <= _heap[i].priority: break
        var tmp = _heap[parent]
        _heap[parent] = _heap[i]
        _heap[i] = tmp
        i = parent

func _sink_down(i: int):
    var n = _heap.size()
    while true:
        var smallest = i
        var l = 2 * i + 1
        var r = 2 * i + 2
        if l < n and _heap[l].priority < _heap[smallest].priority:
            smallest = l
        if r < n and _heap[r].priority < _heap[smallest].priority:
            smallest = r
        if smallest == i: break
        var tmp = _heap[smallest]
        _heap[smallest] = _heap[i]
        _heap[i] = tmp
        i = smallest