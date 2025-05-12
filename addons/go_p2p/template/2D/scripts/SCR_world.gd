extends Node2D

# Player scene reference (set this in the inspector)
@export var player_scene: PackedScene

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
	await  get_tree().create_timer(1).timeout
	for i in multiplayer.get_peers():

		_spawn_player(i)
	#start_multiplayer_game()

func _mp_peer_connected(id: int):
	_spawn_player(id)
	
	# If we're the server/host, send our position to the new client
	if multiplayer.is_server():
		var my_player = spawned_players.get(multiplayer.get_unique_id())
		if my_player:
			my_player.rpc_id(id, "receive_position_update", my_player.global_position)

func _mp_peer_disconnected(id: int):
	_despawn_player(id)

func _spawn_player(id: int):
	# Don't spawn if already exists
	if spawned_players.has(id):
		return
	
	# Instantiate new player
	var new_player = player_scene.instantiate()
	players_node.add_child(new_player)
	
	# Configure player
	new_player.name = str(id)
	new_player.set_multiplayer_authority(id)
	
	# Set as local player if this is our ID
	if id == multiplayer.get_unique_id():
		new_player.is_local_player = true
		# Position local player at spawn point
		new_player.global_position = Vector2(200, 100)  # Set your spawn position
	else:
		new_player.is_local_player = false
		# Position remote players randomly (or use your spawn system)
		new_player.global_position = Vector2(randi_range(100, 500), randi_range(100, 500))
	
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

# Call this when starting/joining a game
func start_multiplayer_game():
	# Spawn local player if in multiplayer
	if multiplayer.has_multiplayer_peer():
		_spawn_player(multiplayer.get_unique_id())
