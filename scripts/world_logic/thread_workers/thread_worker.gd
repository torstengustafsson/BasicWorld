extends RefCounted

# Contains common code for all the thread workers used by the scene

class_name ThreadWorker

var thread: Thread

# Used for having this thread wait for the main threads next frame update
var thread_frame_wait_mutex: Mutex = Mutex.new()
var thread_frame_wait_semaphore: Semaphore = Semaphore.new()
var thread_frame_is_waiting: bool = false

# Used for having the main thread wait for this threads next frame update
var mainthread_frame_wait_mutex: Mutex = Mutex.new()
var mainthread_frame_wait_semaphore: Semaphore = Semaphore.new()
var mainthread_frame_is_waiting: bool = false

var player_pos: Vector3 = Vector3(INF, INF, INF)
var last_player_pos: Vector3 = Vector3(INF, INF, INF)

func _init():
	thread = Thread.new()

func wake_up_thread():
	thread_frame_wait_mutex.lock()
	if thread_frame_is_waiting:
		thread_frame_is_waiting = false
		thread_frame_wait_semaphore.post()
	thread_frame_wait_mutex.unlock()

func wait_for_next_main_frame():
	thread_frame_wait_mutex.lock()
	thread_frame_is_waiting = true
	thread_frame_wait_mutex.unlock()
	thread_frame_wait_semaphore.wait()

func wake_up_mainthread():
	thread_frame_wait_mutex.lock()
	if thread_frame_is_waiting:
		thread_frame_is_waiting = false
		thread_frame_wait_semaphore.post()
	thread_frame_wait_mutex.unlock()

func wait_for_next_thread_frame():
	thread_frame_wait_mutex.lock()
	thread_frame_is_waiting = true
	thread_frame_wait_mutex.unlock()
	thread_frame_wait_semaphore.wait()

func update_player_position(position: Vector3):
	player_pos = position

func stop():
	thread.wait_to_finish()
