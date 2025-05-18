extends Node2D

# Player scene reference (set this in the inspector)
@export var player_scene: PackedScene
@export var bomb: PackedScene

# Player container node
@onready var players_node: Node2D = $Players

# Dictionary to track spawned players by peer ID
var spawned_players := {}
var lastpos = Vector2(100,100)
func _ready():
	# Connect multiplayer signals
	multiplayer.peer_connected.connect(self._mp_peer_connected)
	multiplayer.peer_disconnected.connect(self._mp_peer_disconnected)
	
	# Spawn the local player immediately if we're in a multiplayer session
	if multiplayer.has_multiplayer_peer():
		_spawn_player(multiplayer.get_unique_id())
	
	for i in multiplayer.get_peers():

		_spawn_player(i)

func _mp_peer_connected(id: int):
	_spawn_player(id)
	
func _mp_peer_disconnected(id: int):
	_despawn_player(id)

func _spawn_player(id: int):
	# Don't spawn if already exists
	if spawned_players.has(id):
		return
	
	# Instantiate new player
	var new_player = player_scene.instantiate()
	players_node.add_child(new_player)
	
	new_player.place_bomb.connect(self._place_bomb)
	# Configure player
	new_player.name = str(id)
	
	new_player.set_multiplayer_authority(id)
	
	# Set as local player if this is our ID
	if id == multiplayer.get_unique_id():
		new_player.is_local_player = true
	else:
		new_player.is_local_player = false
		
	new_player.global_position = Vector2(randi_range(0, 10), randi_range(0, 100))
	# Store reference
	spawned_players[id] = new_player
	PrintHelper.debug("Spawned player for peer: %s" % id)

func _despawn_player(id: int):
	if not spawned_players.has(id):
		return
	
	var player = spawned_players[id]
	if is_instance_valid(player):
		player.queue_free()
	
	spawned_players.erase(id)
	PrintHelper.debug("Despawned player for peer: %s" % id)

func _place_bomb(pos):
	var rng = randi_range(5,15)
	_create_bomb.rpc(pos,rng)
	pass

@rpc("any_peer","call_local")
func _create_bomb(pos,time):
	var bomb_instance = bomb.instantiate()
	add_child(bomb_instance)
	bomb_instance.position = pos
	bomb_instance.random_time = time
